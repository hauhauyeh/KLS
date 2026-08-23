using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.Reports;
using Microsoft.AspNetCore.Http;
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
        private const long MaxExtraAttachmentBytes = 25L * 1024L * 1024L;

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
            if (checkoutReq.PurchaseId > 0)
            {
                var purchase = Uow.Purchases.GetById(checkoutReq.PurchaseId)
                    ?? throw new ArgumentException("Purchase order not found.");

                EnsureDropShipReceivedStageEditable(purchase);

                if (purchase.IsDropShip && purchase.StageId is >= 1 and <= 3)
                    throw new ArgumentException("Use the restricted drop-ship PO update.");
            }

            var poId = Uow.PurchaseOrders.Checkout(checkoutReq);

            return GetListById(poId);
        }

        public POList? DropShipRestrictedUpdate(int purchaseId, bool canUpdateShipQty)
        {
            var purchase = Uow.Purchases.GetById(purchaseId)
                ?? throw new ArgumentException("Drop-ship purchase order not found.");

            if (!purchase.IsDropShip || purchase.StageId is null or < 1 or > 3)
                throw new ArgumentException("This operation supports drop-ship PO stages 1 through 3 only.");

            Uow.Purchases.DropShipPORestrictedUpdate(purchaseId, canUpdateShipQty);
            return GetListById(purchaseId);
        }

        private static void EnsureDropShipReceivedStageEditable(Purchase purchase)
        {
            if (purchase.IsDropShip && (purchase.StageId == 4 || purchase.StageId == 5))
                throw new ArgumentException("Read only. Drop-ship receipt is already confirmed. Use Backorder DS for remaining quantities.");
        }

        public void Delete(int PurchaseId)
        {
            var purchase = Uow.Purchases.GetById(PurchaseId);

            // PO and Bill Manager point at the same shared Purchase row.
            // Deleting from PO Manager must remove that same document before
            // convert-to-bill, otherwise Bill Manager still shows the orphaned row.
            if (purchase != null && !purchase.IsLocked)
            {
                if (purchase.IsDropShip)
                {
                    if (purchase.StageId == 6)
                        throw new ArgumentException("Drop-ship Bill must be deleted from Bill Manager.");

                    CancelLinkedDropShipPODelete(purchase, PurchaseId);
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
            var purchase = RequireNormalPurchaseForBill(copyToBillReq.PurchaseId);
            var refs = ResolveBillReferences(
                copyToBillReq.VendorDocNumber,
                copyToBillReq.ContainerNumber,
                purchase);

            copyToBillReq.VendorDocNumber = refs.VendorDocNumber;
            copyToBillReq.ContainerNumber = refs.ContainerNumber;
            PersistBillReferences(copyToBillReq.PurchaseId, refs);

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

        public PurchaseOrderEmailPdfResult EmailPdf(int purchaseId, List<IFormFile>? files = null)
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
                var attachments = BuildPurchaseOrderEmailAttachments(tempFolder, poNumber, poFile, files);
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

        public POList? UpdateToBillStage(int purchaseId, PurchaseOrderConvertToBillReq? req)
        {
            var purchase = RequireNormalPurchaseForBill(purchaseId);
            var refs = ResolveBillReferences(req?.VendorDocNumber, req?.ContainerNumber, purchase);

            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.StageId, x => 6)
            .SetProperty(x => x.VendorDocNumber, x => refs.VendorDocNumber)
            .SetProperty(x => x.ContainerNumber, x => refs.ContainerNumber)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));

            Uow.Shipments.Allocation(purchaseId);

            Uow.VendorPayments.ApplyAdvance(purchaseId);

            return GetListById(purchaseId);
        }

        private Purchase RequireNormalPurchaseForBill(int purchaseId)
        {
            var purchase = Uow.Purchases.GetById(purchaseId)
                ?? throw new KeyNotFoundException($"Purchase order with Id {purchaseId} not found.");

            if (purchase.IsDropShip || purchase.DropShipSalesId != null)
                throw new ArgumentException("Drop-ship PO must be converted from Order Manager.");

            return purchase;
        }

        private static PurchaseOrderConvertToBillReq ResolveBillReferences(string? vendorDocNumber, string? containerNumber, Purchase purchase)
        {
            var refs = new PurchaseOrderConvertToBillReq
            {
                VendorDocNumber = NormalizeUpperRef(vendorDocNumber) ?? NormalizeUpperRef(purchase.VendorDocNumber),
                ContainerNumber = NormalizeContainerNumber(containerNumber) ?? NormalizeContainerNumber(purchase.ContainerNumber)
            };

            if (string.IsNullOrWhiteSpace(refs.VendorDocNumber))
                throw new ArgumentException("V-Doc# is required before converting PO to Bill.");

            if (string.IsNullOrWhiteSpace(refs.ContainerNumber))
                throw new ArgumentException("CONT# is required before converting PO to Bill.");

            return refs;
        }

        private void PersistBillReferences(int purchaseId, PurchaseOrderConvertToBillReq refs)
        {
            Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.VendorDocNumber, x => refs.VendorDocNumber)
            .SetProperty(x => x.ContainerNumber, x => refs.ContainerNumber)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        private static string? NormalizeUpperRef(string? value)
        {
            var normalized = value?.Trim().ToUpperInvariant();
            return string.IsNullOrEmpty(normalized) ? null : normalized;
        }

        private static string? NormalizeContainerNumber(string? value)
        {
            var normalized = NormalizeUpperRef(value);
            if (normalized == null)
                return null;

            var compact = Regex.Replace(normalized, "[^A-Z0-9]", "");
            var match = Regex.Match(compact, "^([A-Z]{4})(\\d{7})$");

            return match.Success
                ? $"{match.Groups[1].Value}-{match.Groups[2].Value}"
                : normalized;
        }

        private string CreateEmailAttachmentFolder()
        {
            var folder = Path.Combine(_env.WebRootPath, "EmailAttachments", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(folder);

            return folder;
        }

        private static string[] BuildPurchaseOrderEmailAttachments(string tempFolder, string poNumber, string poFile, List<IFormFile>? files)
        {
            if (string.IsNullOrWhiteSpace(poFile) || !File.Exists(poFile))
                throw new FileNotFoundException("Generated PO PDF was not found.", poFile);

            var safeNumber = SafeFilePart(poNumber);
            var attachment = Path.Combine(tempFolder, $"PO-{safeNumber}.pdf");
            var attachments = new List<string> { attachment };

            File.Copy(poFile, attachment, true);

            CopyExtraEmailAttachments(tempFolder, files, attachments);

            return attachments.ToArray();
        }

        private static void CopyExtraEmailAttachments(string tempFolder, List<IFormFile>? files, List<string> attachments)
        {
            var selectedFiles = files?.Where(f => f != null).ToList();
            if (selectedFiles == null || selectedFiles.Count == 0)
                return;

            long totalBytes = 0;
            var usedNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var file in selectedFiles)
            {
                if (file.Length <= 0)
                    throw new ArgumentException($"Attachment '{file.FileName}' is empty.");

                totalBytes += file.Length;
                if (totalBytes > MaxExtraAttachmentBytes)
                    throw new ArgumentException("PO email extra attachments exceed the 25 MB total size limit.");

                var safeName = SafeAttachmentFileName(file.FileName);
                var uniqueName = UniqueAttachmentFileName(safeName, usedNames);
                var targetPath = Path.Combine(tempFolder, uniqueName);

                using (var stream = new FileStream(targetPath, FileMode.CreateNew))
                {
                    file.CopyTo(stream);
                }

                attachments.Add(targetPath);
            }
        }

        private static string SafeAttachmentFileName(string? fileName)
        {
            var name = Path.GetFileName(fileName ?? "");
            if (string.IsNullOrWhiteSpace(name))
                name = "attachment";

            var extension = Path.GetExtension(name);
            var baseName = Path.GetFileNameWithoutExtension(name);
            var safeBase = SafeFilePart(baseName);
            var safeExt = Regex.Replace(extension ?? "", @"[^\w.]+", "");

            return safeBase + safeExt;
        }

        private static string UniqueAttachmentFileName(string fileName, HashSet<string> usedNames)
        {
            var name = fileName;
            var extension = Path.GetExtension(fileName);
            var baseName = Path.GetFileNameWithoutExtension(fileName);
            var index = 1;

            while (!usedNames.Add(name))
            {
                index++;
                name = $"{baseName}-{index}{extension}";
            }

            return name;
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
