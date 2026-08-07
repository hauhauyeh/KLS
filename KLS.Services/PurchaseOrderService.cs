using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.Reports;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PurchaseOrderService : BaseService, IPurchaseOrderService
    {
        private readonly IDeleteLogService _deleteLogService;
        private readonly ICompanyService _companyService;
        private readonly IPDFService _pdfService;
        private readonly ISystemSettingService _systemSettingService;
        private readonly IEmailAuditService _emailAuditService;
        private readonly IWebHostEnvironment _env;

        public PurchaseOrderService(IUnitOfWork uow,
            IDeleteLogService deleteLogService,
            ICompanyService companyService,
            IPDFService pdfService,
            ISystemSettingService systemSettingService,
            IEmailAuditService emailAuditService,
            IWebHostEnvironment env) : base(uow)
        {
            _deleteLogService = deleteLogService;
            _companyService = companyService;
            _pdfService = pdfService;
            _systemSettingService = systemSettingService;
            _emailAuditService = emailAuditService;
            _env = env;
        }

        public PagingResponse<POList> GetPagedList(POListReq purchaseOrderReq)
        {
            var list = Uow.PurchaseOrders.GetPagedList(purchaseOrderReq);

            var totalRecords = Uow.PurchaseOrders.Count(purchaseOrderReq);

            return new PagingResponse<POList>(totalRecords, purchaseOrderReq.Pageno, purchaseOrderReq.Pagesize)
            {
                RowData = list,
            };
        }

        public POList? GetListById(int poId)
        {
            var listReq = new POListReq
            {
                Id = poId
            };

            return Uow.PurchaseOrders.GetPagedList(listReq).AsEnumerable().
                FirstOrDefault();
        }

        public POList? Checkout(POCheckoutReq checkoutReq)
        {
            var poId = Uow.PurchaseOrders.Checkout(checkoutReq);

            return GetListById(poId);
        }

        public void Delete(int PurchaseId)
        {
            var purchase = Uow.Purchases.GetById(PurchaseId);

            // PO and Bill Manager point at the same shared Purchase row.
            // Deleting from PO Manager must remove that same document before
            // convert-to-bill, otherwise Bill Manager still shows the orphaned row.
            if (purchase != null && !purchase.IsLocked)
            {
                if (purchase.IsDropShip && purchase.DropShipSalesId != null)
                {
                    CancelLinkedDropShipPurchaseDelete(purchase, PurchaseId);
                }
                else
                {
                    Uow.Purchases.Find(c => c.PurchaseId == PurchaseId).ExecuteDelete();
                }

                string docType = EnumHelper.DocType.Purchase.ToString();

                _deleteLogService.Add(docType, PurchaseId);
            }
        }

        public IEnumerable<PODetail> GetPODetail(int purchaseId)
        {
            return Uow.PurchaseOrders.GetPODetail(purchaseId);
        }

        public POList? CopyToBill(POCopyToBillReq copyToBillReq)
        {
            Uow.PurchaseOrders.CopyToBill(copyToBillReq);

            return GetListById(copyToBillReq.PurchaseId);
        }

        public string PrintPO(int purchaseId)
        {
            var compnayInfo = _companyService.GetDefault();

            var po = Uow.Reports.ReportPO(purchaseId);
            var poDetail = Uow.Reports.ReportPODetail(purchaseId).ToList();

            var rptPO = new RptPOView
            {
                Company = compnayInfo,
                RptPO = po,
                RptPODetail = poDetail,
                PriceDecimals = _systemSettingService.GetPriceDecimals()
            };

            var documentFormat = _systemSettingService.GetByKey<int>(GlobalKey.DOCUMENT_FORMAT);
            var poTemplate = documentFormat == 4
                ? "~/Views/Pdf/PO-4.cshtml"
                : "~/Views/Pdf/PO.cshtml";
            var pohtml = _pdfService.RenderTemplate(poTemplate, rptPO);

            var fileName = "PO-" + purchaseId.ToString() + ".pdf";
            string poFile = Path.Combine(_env.WebRootPath, "Pdf", fileName);

            using (var pdf = _pdfService.HtmlToPDF(pohtml))
            {
                pdf.SaveAs(poFile);
            }

            return poFile;
        }

        public PurchaseOrderEmailPdfResult EmailPdf(int purchaseId)
        {
            var po = GetListById(purchaseId);

            if (po == null)
                throw new KeyNotFoundException($"Purchase order with Id {purchaseId} not found.");

            if (!po.PayeeId.HasValue)
                throw new ArgumentException("PO vendor is missing.");

            var vendor = Uow.Payees.GetById(po.PayeeId.Value);
            var recipient = vendor?.Email?.Trim();

            if (vendor == null || string.IsNullOrWhiteSpace(recipient))
                throw new ArgumentException("Vendor email is missing.");

            var poNumber = po.PurchaseNumber.ToString();
            var poFile = PrintPO(purchaseId);
            var tempFolder = CreateEmailAttachmentFolder();

            try
            {
                var attachments = BuildPurchaseOrderEmailAttachments(tempFolder, poNumber, poFile);
                var subject = $"Purchase Order #{poNumber}";
                var mailbody = BuildPurchaseOrderEmailBody(vendor.PayeeName, poNumber);

                var error = _emailAuditService.SendAndLogSync(new EmailAuditMessage
                {
                    To = recipient,
                    Subject = subject,
                    HtmlBody = mailbody,
                    Attachments = attachments,
                    EmailCategory = EmailAudit.Category.Document,
                    EmailType = EmailAudit.EmailType.PurchaseOrder,
                    PayeeId = vendor.PayeeId,
                    DocumentType = EmailAudit.DocumentType.PurchaseOrder,
                    DocumentId = purchaseId,
                    DocumentNumber = poNumber,
                    Source = EmailAudit.Source.Manual,
                    RequestedBy = UserContext.SystemUserId
                });

                var sent = string.IsNullOrEmpty(error);

                return new PurchaseOrderEmailPdfResult
                {
                    DeliveryStatus = sent ? EmailAudit.DeliveryStatus.Sent : EmailAudit.DeliveryStatus.Failed,
                    Message = sent
                        ? "PO email sent."
                        : "PO email failed.",
                    To = recipient,
                    DocumentNumber = poNumber,
                    AttachmentCount = attachments.Length,
                    ErrorMessage = sent ? null : error
                };
            }
            finally
            {
                DeleteEmailAttachmentFolder(tempFolder);
            }
        }

        public POList? UpdateToBillStage(int purchaseId)
        {
            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.StageId, x => 6)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));

            Uow.Shipments.Allocation(purchaseId);

            Uow.VendorPayments.ApplyAdvance(purchaseId);

            return GetListById(purchaseId);
        }

        private string CreateEmailAttachmentFolder()
        {
            var folder = Path.Combine(_env.WebRootPath, "EmailAttachments", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(folder);

            return folder;
        }

        private static string[] BuildPurchaseOrderEmailAttachments(string tempFolder, string poNumber, string poFile)
        {
            if (string.IsNullOrWhiteSpace(poFile) || !File.Exists(poFile))
                throw new FileNotFoundException("Generated PO PDF was not found.", poFile);

            var safeNumber = SafeFilePart(poNumber);
            var attachment = Path.Combine(tempFolder, $"PO-{safeNumber}.pdf");

            File.Copy(poFile, attachment, true);

            return new[] { attachment };
        }

        private string BuildPurchaseOrderEmailBody(string? vendorName, string poNumber)
        {
            var safeVendorName = WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(vendorName) ? "Vendor" : vendorName);
            var safePoNumber = WebUtility.HtmlEncode(poNumber);
            var companyName = WebUtility.HtmlEncode(_companyService.GetDefault()?.CompanyName ?? "KLS");

            return $"""
                <p>Hello {safeVendorName},</p>
                <p>Please find attached Purchase Order #{safePoNumber}.</p>
                <p>Thank you,<br>{companyName}</p>
                """;
        }

        private static string SafeFilePart(string value)
        {
            var safe = Regex.Replace(value, @"[^\w.-]+", "-").Trim('-');

            return string.IsNullOrWhiteSpace(safe) ? "PO" : safe;
        }

        private static void DeleteEmailAttachmentFolder(string folder)
        {
            try
            {
                if (Directory.Exists(folder))
                    Directory.Delete(folder, true);
            }
            catch
            {
                // Best-effort cleanup only. The email send/log result is already known.
            }
        }
    }
}
