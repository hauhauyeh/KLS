using IronPdf;
using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.Reports;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Square;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;

namespace KLS.Services
{
    public class SalesService : BaseService, ISalesService
    {
        private readonly IWebHostEnvironment _env;
        private readonly IDocumentService _documentService;
        private readonly IEmailSettingService _emailSettingService;
        private readonly IEmailService _emailService;
        private readonly IEmailAuditService _emailAuditService;
        private readonly IExportService _exportService;
        private readonly ITwilioService _twilioService;
        private readonly IPortalModeService _portalModeService;
        private readonly ISquareService _squareService;
        private readonly IMxMerchantService _mxMerchantService;
        private readonly IMemoryCache _memoryCache;
        private readonly ISystemSettingService _systemSettingService;
        private readonly ISalesOrderDocumentStageEffectService _salesOrderDocumentStageEffectService;

        public SalesService(IUnitOfWork uow,
            IWebHostEnvironment env,
            IDocumentService documentService,
            IEmailSettingService emailSettingService,
            IEmailService emailService,
            IEmailAuditService emailAuditService,
            IExportService exportService,
            ITwilioService twilioService,
            IPortalModeService portalModeService,
            ISquareService squareService,
            IMxMerchantService mxMerchantService,
            IMemoryCache memoryCache,
            ISystemSettingService systemSettingService,
            ISalesOrderDocumentStageEffectService salesOrderDocumentStageEffectService) : base(uow)
        {
            _env = env;
            _documentService = documentService;
            _emailSettingService = emailSettingService;
            _emailService = emailService;
            _emailAuditService = emailAuditService;
            _exportService = exportService;
            _twilioService = twilioService;
            _portalModeService = portalModeService;
            _squareService = squareService;
            _mxMerchantService = mxMerchantService;
            _memoryCache = memoryCache;
            _systemSettingService = systemSettingService;
            _salesOrderDocumentStageEffectService = salesOrderDocumentStageEffectService;
        }

        public PagingResponse<SalesList> GetPagedList(SalesListReq salesListReq)
        {
            var sales = Uow.Sales.GetPagedList(salesListReq).ToList();

            var totalRecords = Uow.Sales.Count(salesListReq);

            foreach (var invoice in sales)
            {
                invoice.IsPdfExist = IsInvoicePdfExist(invoice.SalesNumber);
            }

            return new PagingResponse<SalesList>(totalRecords, salesListReq.Pageno, salesListReq.Pagesize)
            {
                RowData = sales,
            };
        }

        public void EnsureVisible(int salesId)
        {
            EnsureVisibleSales(salesId);
        }

        public void EnsureVisibleSalesNumber(int salesNumber)
        {
            if (!UserContext.IsSalesRole)
                return;

            var salesId = Uow.Sales.Find(s => s.SalesNumber == salesNumber)
                .Select(s => (int?)s.SalesId)
                .FirstOrDefault();

            if (!salesId.HasValue)
                throw new KeyNotFoundException($"Sales with number {salesNumber} not found.");

            EnsureVisible(salesId.Value);
        }

        public Sales GetById(int salesId)
        {
            EnsureVisible(salesId);

            return Uow.Sales.GetById(salesId);
        }

        public Sales? GetBySalesNumber(int salesNumber)
        {
            return Uow.Sales.Find(c => c.SalesNumber == salesNumber).FirstOrDefault();
        }

        private bool UseSalesDocNumber()
        {
            return _systemSettingService.GetByKey<bool>(GlobalKey.SALES_DOC_NUMBER_DISPLAY_ENABLED);
        }

        private string SalesDisplayNumber(Sales sales)
        {
            if (UseSalesDocNumber() && !string.IsNullOrWhiteSpace(sales.SalesDocNumber))
                return sales.SalesDocNumber;

            return sales.SalesNumber.ToString();
        }

        private string SalesDisplayNumber(SalesList sales)
        {
            if (UseSalesDocNumber() && !string.IsNullOrWhiteSpace(sales.SalesDocNumber))
                return sales.SalesDocNumber;

            return sales.SalesNumber.ToString();
        }

        public SalesList? GetListById(int salesId)
        {
            var listReq = new SalesListReq
            {
                Id = salesId
            };

            return Uow.Sales.GetPagedList(listReq).AsEnumerable().FirstOrDefault();
        }

        public Sales UpdateShipRoute(int salesId, string? shipRoute)
        {
            EnsureVisible(salesId);

            var sales = GetById(salesId);

            if (sales != null)
            {
                if (shipRoute?.Length > 1 && shipRoute != "CM")
                {
                    var load = shipRoute.Last();

                    if (Char.IsNumber(load))
                    {
                        sales.IsLoadSeparate = true;
                        string letters = Regex.Replace(shipRoute, @"\d", "");

                        sales.ShipRoute = letters;
                    }
                    else
                        sales.ShipRoute = shipRoute;
                }
                else
                {
                    sales.ShipRoute = string.IsNullOrEmpty(shipRoute) ? null : shipRoute;
                }

                sales.UpdatedAt = DateTime.UtcNow;

                // 2026-05-09: keep TruckNumber/Deliverby in sync with the new ShipRoute.
                // Without this, rerouted Sales rows kept the old route's truck/driver
                // until Print Invoice ran UpdateInvoice and corrected them.
                SyncTruckDriverFromRoute(sales);

                Uow.Sales.Update(sales);
                Uow.Commit();
            }

            return sales;
        }

        // 2026-05-09: After Phase 5 (2026-05-03), Sales.TruckNumber/Deliverby are
        // owned by SalesRoute. Any path that mutates Sales.ShipRoute must re-sync
        // truck/driver from SalesRoute or those columns go stale until the next
        // SaveAssignTrucks / UpdateInvoice (Print Invoice) corrects them.
        private void SyncTruckDriverFromRoute(Sales sales)
        {
            if (string.IsNullOrEmpty(sales.ShipRoute))
            {
                sales.TruckNumber = null;
                sales.Deliverby = null;
                return;
            }

            var route = Uow.SalesRoutes
                .Find(r => r.ShipDate == sales.ShipDate && r.ShipRoute == sales.ShipRoute)
                .FirstOrDefault();

            sales.TruckNumber = route?.TruckNumber;
            sales.Deliverby = route?.DriverId;
        }

        public void UpdateInstruction(int salesId, string? instruction)
        {
            EnsureVisible(salesId);

            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.Instruction, x => instruction)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void UpdatePO(int salesId, string? custPO)
        {
            EnsureVisible(salesId);

            custPO = string.IsNullOrWhiteSpace(custPO) ? null : custPO.Trim().ToUpper();

            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.CustPONumber, x => custPO)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void UpdateLoadSeparate(int salesId)
        {
            if (!_systemSettingService.GetByKey<bool>(GlobalKey.SALES_LOAD_SEPARATE))
                throw new InvalidOperationException("Load Separate is disabled for this company.");

            EnsureVisible(salesId);

            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
           .SetProperty(x => x.IsLoadSeparate, x => !x.IsLoadSeparate)
           .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public SalesList UpdateCarrier(int salesId, int? shippingCarrierId)
        {
            EnsureVisible(salesId);

            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
           .SetProperty(x => x.ShippingCarrierId, x => shippingCarrierId)
           .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));

            return GetListById(salesId)!;
        }

        public SalesStage UpdateStage(int salesId, int stageId)
        {
            EnsureVisible(salesId);

            return Uow.Sales.UpdateStage(salesId, stageId);
        }

        public SalesStage EnterEditMode(int salesId)
        {
            EnsureVisible(salesId);

            var sales = GetById(salesId);

            if (sales == null)
                throw new KeyNotFoundException($"Sales with Id {salesId} not found.");

            if ((sales.StageId ?? 0) >= 4)
                throw new InvalidOperationException("Cannot edit delivered orders.");

            return Uow.Sales.EnterEditMode(salesId);
        }

        public SalesStage RestoreStage(int salesId, int stageId)
        {
            EnsureVisible(salesId);

            return Uow.Sales.RestoreStage(salesId, stageId);
        }

        public void Delete(int salesId)
        {
            EnsureVisible(salesId);

            var sales = Uow.Sales.GetById(salesId);

            if (sales != null && !sales.IsLocked)
            {
                // Slice 3 (drop-ship): block deletion only while a live linked PO/Bill still exists.
                // If PO Manager previously deleted the PO without unlinking the SO, allow deleting the stale SO.
                var hasLiveDropShipPurchase = Uow.Purchases.Exists(p =>
                    (sales.DropShipPurchaseId != null && p.PurchaseId == sales.DropShipPurchaseId)
                    || p.DropShipSalesId == salesId);

                if ((sales.IsDropShip || sales.DropShipPurchaseId != null) && hasLiveDropShipPurchase)
                    throw new ArgumentException("This sales order has a linked drop-ship PO. Delete or unlink the PO first.");

                Uow.Sales.Find(c => c.SalesId == salesId).ExecuteDelete();
            }
        }

        public ICollection<string?> GetShipRoutes(DateOnly shipDate)
        {
            return Uow.Sales.Find(c => c.ShipDate == shipDate).OrderBy(c => c.ShipRoute).Select(c => c.ShipRoute).Distinct().ToList();
        }

        public void Inject(int salesId)
        {
            EnsureVisible(salesId);

            Uow.Sales.Inject(salesId);
        }

        public SalesList Checkout(SalesCheckoutReq checkoutReq)
        {
            EnsureVisibleCustomer(checkoutReq.PayeeId);

            var salesId = Uow.Sales.Checkout(checkoutReq);
            var sales = GetListById(salesId)!;
            AutoPrintPickTicket(sales.SalesId, sales.SalesNumber);

            return sales;
        }

        public SalesList UpdatePartially(int salesId)
        {
            EnsureVisible(salesId);

            Uow.Sales.UpdatePartially(salesId);

            return GetListById(salesId)!;
        }

        public SalesList UpdateNameDate(SalesUpdateReq updateReq)
        {
            EnsureVisible(updateReq.SalesId);

            if (updateReq.IsNameChange && updateReq.PayeeId.HasValue)
                EnsureVisibleCustomer(updateReq.PayeeId.Value);

            Uow.Sales.UpdateNameDate(updateReq);

            return GetListById(updateReq.SalesId)!;
        }

        public SalesList InsertShippingCharge(SalesUpdateReq updateReq)
        {
            EnsureVisible(updateReq.SalesId);

            Uow.Sales.InsertShippingCharge(updateReq);

            return GetListById(updateReq.SalesId)!;
        }

        public bool IsInvoicePdfExist(int salesNumber)
        {
            // Get absolute path to wwwroot/InvoicePdf
            var pdfFile = Path.Combine(_env.WebRootPath, "InvoicePdf", salesNumber + ".pdf");

            return File.Exists(pdfFile);
        }

        public IEnumerable<ShipRouteDetail>? GetByDateRoute(SalesDateRouteReq dateRouteReq)
        {
            return Uow.Sales.GetByDateRoute(dateRouteReq.ShipDate, dateRouteReq.ShipRoute);
        }

        public void BatchAllocation(DateOnly shipDate)
        {
            Uow.Sales.BatchAllocation(shipDate);
        }

        public void SingleAllocation(int salesId)
        {
            Uow.Sales.SingleAllocation(salesId);
        }

        public SalesEmailInvoiceResult EmailPdf(int salesId)
        {
            EnsureVisible(salesId);

            var sales = GetById(salesId);

            if (sales == null)
                throw new KeyNotFoundException($"Sales with Id {salesId} not found.");

            var salesDisplayNumber = SalesDisplayNumber(sales);
            var recipient = GetInvoiceEmailRecipient(sales);

            if (recipient.Payee == null || string.IsNullOrEmpty(recipient.Email))
                throw new InvalidOperationException("Customer does not have an invoice email address.");

            var cleanInvoiceFile = _documentService.Invoice(new DocumentReq { SalesId = salesId, SalesNumber = sales.SalesNumber });
            var signedBolFile = GetSignedBolPath(sales.SalesNumber);
            var tempFolder = CreateEmailAttachmentFolder();

            try
            {
                var attachments = BuildInvoiceEmailAttachments(tempFolder, salesDisplayNumber, cleanInvoiceFile, signedBolFile);
                var subject = $"Invoice {salesDisplayNumber}";
                var mailbody = BuildInvoiceEmailBody(recipient.Payee.PayeeName, salesDisplayNumber);

                var error = _emailAuditService.SendAndLogSync(new EmailAuditMessage
                {
                    To = recipient.Email,
                    Subject = subject,
                    HtmlBody = mailbody,
                    Attachments = attachments,
                    EmailCategory = EmailAudit.Category.Document,
                    EmailType = EmailAudit.EmailType.Invoice,
                    PayeeId = recipient.Payee.PayeeId,
                    DocumentType = EmailAudit.DocumentType.Invoice,
                    DocumentId = salesId,
                    DocumentNumber = salesDisplayNumber,
                    Source = EmailAudit.Source.Manual,
                    RequestedBy = UserContext.SystemUserId
                });

                var sent = string.IsNullOrEmpty(error);

                if (sent)
                    _salesOrderDocumentStageEffectService.ApplyAfterSuccess(salesId, SalesOrderDocumentActionKeys.EmailInvoice);

                return new SalesEmailInvoiceResult
                {
                    DeliveryStatus = sent ? EmailAudit.DeliveryStatus.Sent : EmailAudit.DeliveryStatus.Failed,
                    Message = sent
                        ? "Invoice email sent."
                        : "Invoice email failed.",
                    To = recipient.Email,
                    DocumentNumber = salesDisplayNumber,
                    SignedBolAttached = !string.IsNullOrEmpty(signedBolFile),
                    AttachmentCount = attachments.Length,
                    ErrorMessage = sent ? null : error
                };
            }
            finally
            {
                DeleteEmailAttachmentFolder(tempFolder);
            }
        }

        private (Payee? Payee, string? Email) GetInvoiceEmailRecipient(Sales sales)
        {
            Payee? billTo = sales.BillId.HasValue
                ? Uow.Payees.GetById(sales.BillId.Value)
                : null;
            var billToEmail = FirstEmail(billTo?.EmailInvoice, billTo?.Email);

            if (billTo != null && !string.IsNullOrEmpty(billToEmail))
                return (billTo, billToEmail);

            Payee? shipTo = sales.ShipId.HasValue
                ? Uow.Payees.GetById(sales.ShipId.Value)
                : null;
            var shipToEmail = FirstEmail(shipTo?.EmailInvoice, shipTo?.Email);

            if (shipTo != null && !string.IsNullOrEmpty(shipToEmail))
                return (shipTo, shipToEmail);

            return (billTo ?? shipTo, null);
        }

        private string? GetSignedBolPath(int salesNumber)
        {
            var path = Path.Combine(_env.WebRootPath, "InvoicePdf", salesNumber + ".pdf");

            return File.Exists(path) ? path : null;
        }

        private string CreateEmailAttachmentFolder()
        {
            var folder = Path.Combine(_env.WebRootPath, "EmailAttachments", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(folder);

            return folder;
        }

        private static string[] BuildInvoiceEmailAttachments(string tempFolder, string salesDisplayNumber, string cleanInvoiceFile, string? signedBolFile)
        {
            if (string.IsNullOrWhiteSpace(cleanInvoiceFile) || !File.Exists(cleanInvoiceFile))
                throw new FileNotFoundException("Generated invoice PDF was not found.", cleanInvoiceFile);

            var safeNumber = SafeFilePart(salesDisplayNumber);
            var attachments = new List<string>();
            var cleanInvoiceAttachment = Path.Combine(tempFolder, $"Invoice-{safeNumber}.pdf");

            File.Copy(cleanInvoiceFile, cleanInvoiceAttachment, true);
            attachments.Add(cleanInvoiceAttachment);

            if (!string.IsNullOrEmpty(signedBolFile) && File.Exists(signedBolFile))
            {
                var signedBolAttachment = Path.Combine(tempFolder, $"Signed-BOL-{safeNumber}.pdf");
                File.Copy(signedBolFile, signedBolAttachment, true);
                attachments.Add(signedBolAttachment);
            }

            return attachments.ToArray();
        }

        private string BuildInvoiceEmailBody(string? payeeName, string salesDisplayNumber)
        {
            var customerName = WebUtility.HtmlEncode(string.IsNullOrWhiteSpace(payeeName) ? "Customer" : payeeName);
            var invoiceNumber = WebUtility.HtmlEncode(salesDisplayNumber);
            var paymentInstructions = _systemSettingService.GetByKey<string>(GlobalKey.INVOICE_EMAIL_PAYMENT_INSTRUCTIONS);
            var paymentBlock = string.IsNullOrWhiteSpace(paymentInstructions)
                ? ""
                : Environment.NewLine + paymentInstructions.Trim();

            return $"""
                <p>Hello {customerName},</p>
                <p>Please find attached invoice {invoiceNumber}.</p>
                <p>If available, the signed Bill of Lading is attached for your records.</p>
                {paymentBlock}
                <p>Thank you.</p>
                """;
        }

        private static string SafeFilePart(string value)
        {
            var safe = Regex.Replace(value, @"[^\w.-]+", "-").Trim('-');

            return string.IsNullOrWhiteSpace(safe) ? "Invoice" : safe;
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

        private static string? FirstEmail(params string?[] emails)
        {
            foreach (var email in emails)
            {
                if (!string.IsNullOrWhiteSpace(email))
                    return email.Trim();
            }

            return null;
        }

        public int MergeOrder(SalesMergeReq mergeReq)
        {
            foreach (var salesId in ParsePositiveInts(mergeReq.SalesIds, nameof(mergeReq.SalesIds)))
            {
                EnsureVisible(salesId);
            }

            return Uow.Sales.MergeOrder(mergeReq);
        }

        public string MergePdf(string salesNumbers)
        {
            if (string.IsNullOrWhiteSpace(salesNumbers))
                throw new ArgumentException("SalesNumbers is required.", nameof(salesNumbers));

            var mergeFolder = Path.Combine(_env.WebRootPath, "MergeInvoice");
            Directory.CreateDirectory(mergeFolder);

            var tempFileName = $"{DateTime.UtcNow:yyyyMMddHHmmssfff}";
            var mergedPdfPath = Path.Combine(mergeFolder, tempFileName + ".pdf");

            var ids = ParsePositiveInts(salesNumbers, nameof(salesNumbers));

            foreach (var salesNumber in ids)
            {
                EnsureVisibleSalesNumber(salesNumber);
            }

            var docs = new List<PdfDocument>(ids.Count);

            try
            {
                foreach (var salesNum in ids)
                {
                    var pdfPath = Path.Combine(_env.WebRootPath, "InvoicePdf", salesNum.ToString() + ".pdf");
                    if (!File.Exists(pdfPath))
                        continue;

                    docs.Add(PdfDocument.FromFile(pdfPath));
                }

                if (docs.Count == 0)
                    throw new FileNotFoundException("No PDF files found to merge.");

                using var merged = PdfDocument.Merge(docs);
                merged.SaveAs(mergedPdfPath);

                return mergedPdfPath;
            }
            finally
            {
                foreach (var d in docs)
                    d?.Dispose();
            }
        }

        private static List<int> ParsePositiveInts(string? value, string fieldName)
        {
            if (string.IsNullOrWhiteSpace(value))
                throw new ArgumentException($"{fieldName} is required.", fieldName);

            var ids = new List<int>();

            foreach (var part in value.Split(',', StringSplitOptions.RemoveEmptyEntries))
            {
                var trimmed = part.Trim();

                if (!int.TryParse(trimmed, out var id) || id <= 0)
                    throw new ArgumentException($"{fieldName} contains an invalid id: {trimmed}.", fieldName);

                if (!ids.Contains(id))
                    ids.Add(id);
            }

            if (ids.Count == 0)
                throw new ArgumentException($"{fieldName} is required.", fieldName);

            return ids;
        }

        public SalesSeePayment SeePayment(int salesId)
        {
            EnsureVisible(salesId);

            var payments = (from c in Uow.CustomerPayments.GetAll()
                            join cd in Uow.CustomerPaymentDetails.GetAll() on c.CustomerPaymentId equals cd.CustomerPaymentId
                            where cd.SalesId == salesId
                            select c).ToList();

            return new SalesSeePayment
            {
                Sales = GetById(salesId),
                CustomerPayments = payments
            };
        }

        public IEnumerable<SalesList>? OpenInvoices(int payeeId)
        {
            EnsureVisibleCustomer(payeeId);

            var sales = Uow.Sales.GetPagedList(new SalesListReq
            {
                Pagesize = 500,
                PayeeId = payeeId,
                Filterby = "unpaid",
                SortField = "ShipDate",
                SortOrder = "Asc"
            }).ToList();

            foreach (var invoice in sales)
            {
                invoice.IsPdfExist = IsInvoicePdfExist(invoice.SalesNumber);
            }

            return sales;
        }

        public IEnumerable<SalesList>? PastDueInvoices(int payeeId)
        {
            EnsureVisibleCustomer(payeeId);

            var sales = Uow.Sales.GetPagedList(new SalesListReq
            {
                Pagesize = 500,
                PayeeId = payeeId,
                Filterby = "pastdue",
                SortField = "ShipDate",
                SortOrder = "Asc"
            }).ToList();

            foreach (var invoice in sales)
            {
                invoice.IsPdfExist = IsInvoicePdfExist(invoice.SalesNumber);
            }

            return sales;
        }

        public IEnumerable<CustBoughtItemPanelRow> CustBoughtItemsPanel(int payeeId)
        {
            EnsureVisibleCustomer(payeeId);

            return Uow.Reports.CustBoughtItemsPanel(payeeId).ToList();
        }

        public byte[] Export(SalesExportReq exportReq)
        {
            var sales = Uow.Sales.Export(exportReq);

            return _exportService.ToExcel(sales, "Sales");
        }


        public IEnumerable<ShipRouteSummary>? ShipRouteSummary(DateOnly shipDate)
        {
            var summary = Uow.Sales.ShipRouteSummary(shipDate)?.ToList();

            if (summary == null) return null;

            var routeDetail = Uow.Sales.ShipRouteDetail(shipDate)?.ToList();

            foreach (var s in summary)
            {
                s.ShipRouteDetails = routeDetail?.Where(c => c.ShipRoute == s.ShipRoute).ToList();
            }

            return summary;
        }

        public void UpdateRouteOrder(List<ShipRouteDetail> routeDetails)
        {
            foreach (var route in routeDetails)
            {
                Uow.Sales.Find(c => c.SalesId == route.SalesId).ExecuteUpdate(setters => setters
                .SetProperty(x => x.RouteOrder, x => route.RouteOrder)
                .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
            }
        }

        // Old (2026-05-09 replaced):
        // ExecuteUpdate ran one UPDATE per row and only touched ShipRoute/IsLoadSeparate,
        // leaving Sales.TruckNumber/Deliverby stale after a route change. Switched to
        // entity-based update so SyncTruckDriverFromRoute can run per row.
        // public void UpdateRoute(List<ShipRouteDetail> routeDetails)
        // {
        //     foreach (var route in routeDetails)
        //     {
        //         Uow.Sales.Find(c => c.SalesId == route.SalesId).ExecuteUpdate(setters => setters
        //         .SetProperty(x => x.ShipRoute, x => route.ShipRoute)
        //         .SetProperty(x => x.IsLoadSeparate, x => route.IsLoadSeparate)
        //         .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        //     }
        // }
        public void UpdateRoute(List<ShipRouteDetail> routeDetails)
        {
            if (routeDetails == null || routeDetails.Count == 0)
                return;

            var salesIds = routeDetails.Select(r => r.SalesId).Distinct().ToList();
            var salesRows = Uow.Sales.Find(s => salesIds.Contains(s.SalesId)).ToList();
            var detailMap = routeDetails.ToDictionary(r => r.SalesId);

            foreach (var sales in salesRows)
            {
                if (!detailMap.TryGetValue(sales.SalesId, out var detail)) continue;

                sales.ShipRoute = detail.ShipRoute;
                sales.IsLoadSeparate = detail.IsLoadSeparate;
                sales.UpdatedAt = DateTime.UtcNow;

                SyncTruckDriverFromRoute(sales);

                Uow.Sales.Update(sales);
            }

            Uow.Commit();
        }

        public SalesDetailDto? GetSalesDetails(int salesId)
        {
            EnsureVisible(salesId);

            var details = Uow.Sales.GetSalesDetails(salesId);

            return new SalesDetailDto
            {
                Sales = GetListById(salesId),
                SalesDetails = details?.ToList()
            };
        }

        //--Web
        public PagingResponse<OrderWebList>? GetWebPagedList(SalesListReq salesListReq)
        {
            salesListReq.PayeeId = UserContext.EmpId;

            var sales = Uow.Sales.GetWebPagedList(salesListReq).ToList();

            var totalRecords = Uow.Sales.WebOrderCount(salesListReq);

            foreach (var invoice in sales)
            {
                invoice.IsPdfExist = IsInvoicePdfExist(invoice.SalesNumber);
            }

            return new PagingResponse<OrderWebList>(totalRecords, salesListReq.Pageno, salesListReq.Pagesize)
            {
                RowData = sales,
            };
        }

        public int WebCheckout(SalesWebCheckoutReq webCheckoutReq)
        {
            var checkoutReq = new SalesCheckoutReq
            {
                PayeeId = UserContext.EmpId,
                StageId = 0,
                Instruction = "Web " + webCheckoutReq.Instruction,
                ShipDate = webCheckoutReq.ShipDate,
                ShipRoute = webCheckoutReq.ShipRoute
            };

            var customer = Uow.Customers.GetById(UserContext.EmpId);

            if (customer != null)
                checkoutReq.ShipRoute = customer.DefaultRoute;

            if (webCheckoutReq.IsPickUp)
                checkoutReq.ShipRoute = "P";

            var salesId = Uow.Sales.Checkout(checkoutReq);

            var payee = Uow.Payees.GetById(UserContext.EmpId);

            if (payee.Email != webCheckoutReq.Email)
            {
                payee.Email = webCheckoutReq.Email;
                payee.UpdatedAt = DateTime.UtcNow;

                Uow.Payees.Update(payee);
            }

            if (customer.TextOrderConfirm != webCheckoutReq.Phone)
            {
                customer.TextOrderConfirm = webCheckoutReq.Phone;

                Uow.Customers.Update(customer);
            }

            Uow.Commit();

            var sales = GetById(salesId);

            var toPhone = customer.TextOrderConfirm;

            if (!string.IsNullOrEmpty(toPhone))
            {
                string msgbody = "Dear " + payee.PayeeName + "! We've received your order. Your order number " + SalesDisplayNumber(sales) + " will be ship on " + sales.ShipDate?.ToString("MM/dd/yyyy") + ".";

                _twilioService.SendMessage(toPhone, msgbody);
            }

            EmailOrderDetail(salesId);
            AutoPrintPickTicket(sales.SalesId, sales.SalesNumber);

            return sales.SalesId;
        }

        public int WebCheckoutB2C(SalesB2cCheckoutReq webCheckoutReq)
        {
            if (!_portalModeService.IsB2C())
                throw new InvalidOperationException("B2C checkout is only available in B2C mode.");

            if (string.IsNullOrWhiteSpace(webCheckoutReq.ClientRequestKey))
                throw new InvalidOperationException("Client request key is required.");

            var cacheKey = $"b2c-checkout:{UserContext.EmpId}:{webCheckoutReq.ClientRequestKey}";

            if (_memoryCache.TryGetValue<int>(cacheKey, out var existingSalesId) && existingSalesId > 0)
                return existingSalesId;

            var cartItems = Uow.TempSales.GetList(new TempSalesReq { PayeeId = UserContext.EmpId, SalesId = 0 })?.ToList() ?? [];
            if (cartItems.Count == 0)
                throw new InvalidOperationException("Cart is empty.");

            var dueTotal = cartItems.Sum(x => x.ExtTotal ?? 0m);
            if (dueTotal <= 0)
                throw new InvalidOperationException("Cart total must be greater than zero.");

            var payment = ChargeB2CPayment(webCheckoutReq, dueTotal);

            var checkoutReq = new SalesCheckoutReq
            {
                PayeeId = UserContext.EmpId,
                StageId = 0,
                Instruction = "Web " + webCheckoutReq.Instruction,
                ShipDate = webCheckoutReq.ShipDate,
                ShipRoute = webCheckoutReq.ShipRoute
            };

            if (webCheckoutReq.IsPickUp)
                checkoutReq.ShipRoute = "P";

            var salesIdCreated = Uow.Sales.Checkout(checkoutReq);
            SaveGatewayPaymentForSales(payment, salesIdCreated, UserContext.EmpId);
            UpdateB2CCheckoutContact(webCheckoutReq);
            Uow.Commit();

            var sales = GetById(salesIdCreated);
            var customer = Uow.Customers.GetById(UserContext.EmpId);
            var toPhone = customer?.TextOrderConfirm;

            if (!string.IsNullOrEmpty(toPhone))
            {
                var payee = Uow.Payees.GetById(UserContext.EmpId);
                string msgbody = "Dear " + payee.PayeeName + "! We've received your order. Your order number " + SalesDisplayNumber(sales) + " will be ship on " + sales.ShipDate?.ToString("MM/dd/yyyy") + ".";

                _twilioService.SendMessage(toPhone, msgbody);
            }

            EmailOrderDetail(salesIdCreated);
            AutoPrintPickTicket(salesIdCreated, sales.SalesNumber);
            _memoryCache.Set(cacheKey, salesIdCreated, TimeSpan.FromMinutes(30));

            return salesIdCreated;
        }

        private void UpdateB2CCheckoutContact(SalesB2cCheckoutReq webCheckoutReq)
        {
            var payee = Uow.Payees.GetById(UserContext.EmpId);
            if (payee != null && payee.Email != webCheckoutReq.Email)
            {
                payee.Email = webCheckoutReq.Email;
                payee.UpdatedAt = DateTime.UtcNow;
                Uow.Payees.Update(payee);
            }

            var customer = Uow.Customers.GetById(UserContext.EmpId);
            if (customer != null && customer.TextOrderConfirm != webCheckoutReq.Phone)
            {
                customer.TextOrderConfirm = webCheckoutReq.Phone;
                Uow.Customers.Update(customer);
            }
        }

        private void AutoPrintPickTicket(int salesId, int salesNumber)
        {
            var autoPrint = _systemSettingService.GetByKey<bool>(GlobalKey.AUTO_PRINTINVOICE);
            if (!autoPrint) return;

            _documentService.PickTicket(new DocumentReq
            {
                SalesId = salesId,
                SalesNumber = salesNumber,
                IsPrint = true
            });
        }

        private void SaveGatewayPaymentForSales(B2CPaymentResult payment, int salesId, int payeeId)
        {
            var paymentReq = new CreateGatewayPaymentReq
            {
                PayeeId = payeeId,
                PaymentMethod = payment.PaymentMethod,
                ReferenceId = payment.ReferenceId,
                PaymentAmount = payment.PaymentAmount,
                SalesIds = salesId.ToString(),
                Gateway = payment.Gateway,
                CCFee = payment.CCFee,
                CardType = payment.CardType,
                Last4 = payment.Last4
            };

            Uow.CustomerPayments.SaveGatewayPayment(paymentReq);
        }

        private B2CPaymentResult ChargeB2CPayment(SalesB2cCheckoutReq webCheckoutReq, decimal dueTotal)
        {
            if (webCheckoutReq.PaymentMethodId.HasValue)
            {
                var method = Uow.PaymentMethods.GetById(webCheckoutReq.PaymentMethodId.Value);
                if (method == null)
                    throw new InvalidOperationException("Payment method not found.");

                if (method.IsACH)
                {
                    var mxResp = _mxMerchantService
                        .ChargeAsync(method, dueTotal, true)
                        .GetAwaiter()
                        .GetResult();

                    return new B2CPaymentResult
                    {
                        Gateway = "MX Merchant",
                        PaymentMethod = "E-CHECK",
                        PaymentAmount = dueTotal,
                        ReferenceId = ExtractMxReferenceId(mxResp),
                        Last4 = method.Last4
                    };
                }

                var ccFee = Utilities.Rounding((webCheckoutReq.CCFeePercent ?? 0m) * dueTotal, 2) ?? 0m;
                var paymentAmount = dueTotal + ccFee;
                var paymentAmountCent = Convert.ToInt64(paymentAmount * 100m);
                var sqCustId = !string.IsNullOrEmpty(method.SQCustId)
                    ? Utilities.Decrypt(method.SQCustId)
                    : Uow.Customers.GetById(method.PayeeId)?.SquareId;

                var paymentResponse = _squareService
                    .ChargePayment(UserContext.EmpId, sqCustId, Utilities.Decrypt(method.SQCardId), paymentAmountCent, webCheckoutReq.ClientRequestKey)
                    .GetAwaiter()
                    .GetResult();

                ValidateSquareResponse(paymentResponse);

                return new B2CPaymentResult
                {
                    Gateway = "Square Payment",
                    PaymentMethod = "CREDIT CARD",
                    PaymentAmount = paymentAmount,
                    ReferenceId = paymentResponse.Payment?.Id,
                    CCFee = ccFee,
                    CardType = Convert.ToString(paymentResponse.Payment?.CardDetails?.Card?.CardBrand),
                    Last4 = Convert.ToString(paymentResponse.Payment?.CardDetails?.Card?.Last4)
                };
            }

            if (webCheckoutReq.PaymentMethod == null)
                throw new InvalidOperationException("Payment method is required.");

            webCheckoutReq.PaymentMethod.PayeeId = UserContext.EmpId;

            if (webCheckoutReq.PaymentMethod.IsACH)
            {
                var mxResp = _mxMerchantService
                    .ChargeAsync(webCheckoutReq.PaymentMethod, dueTotal, false)
                    .GetAwaiter()
                    .GetResult();

                return new B2CPaymentResult
                {
                    Gateway = "MX Merchant",
                    PaymentMethod = "E-CHECK",
                    PaymentAmount = dueTotal,
                    ReferenceId = ExtractMxReferenceId(mxResp),
                    Last4 = Utilities.GetLast4(webCheckoutReq.PaymentMethod.AccountNumber)
                };
            }

            var ccFeeDirect = Utilities.Rounding((webCheckoutReq.CCFeePercent ?? 0m) * dueTotal, 2) ?? 0m;
            var paymentAmountDirect = dueTotal + ccFeeDirect;
            var directMxResp = _mxMerchantService
                .ChargeAsync(webCheckoutReq.PaymentMethod, paymentAmountDirect, false)
                .GetAwaiter()
                .GetResult();

            return new B2CPaymentResult
            {
                Gateway = "MX Merchant",
                PaymentMethod = "CREDIT CARD",
                PaymentAmount = paymentAmountDirect,
                ReferenceId = ExtractMxReferenceId(directMxResp),
                CCFee = ccFeeDirect,
                CardType = webCheckoutReq.PaymentMethod.AccountType,
                Last4 = Utilities.GetLast4(webCheckoutReq.PaymentMethod.AccountNumber)
            };
        }

        private static void ValidateSquareResponse(CreatePaymentResponse paymentResponse)
        {
            if (paymentResponse?.Payment == null)
                throw new Exception("Payment gateway returned an empty response.");

            if (!string.Equals(paymentResponse.Payment.Status, "COMPLETED", StringComparison.OrdinalIgnoreCase))
            {
                var errorMsg = paymentResponse.Errors != null && paymentResponse.Errors.Any()
                    ? string.Join(" | ", paymentResponse.Errors.Select(e => $"{e.Code}: {e.Detail}"))
                    : $"Payment was not completed. Status: {paymentResponse.Payment.Status}";

                throw new Exception(errorMsg);
            }
        }

        private static string ExtractMxReferenceId(MxCreatePaymentResponse mxResp)
        {
            if (mxResp == null || mxResp.Extra.Count == 0) return "";

            string? TryGet(string key)
                => mxResp.Extra
                    .FirstOrDefault(kv => string.Equals(kv.Key, key, StringComparison.OrdinalIgnoreCase))
                    .Value?.ToString();

            return TryGet("reference")
                ?? TryGet("referenceNumber")
                ?? TryGet("id")
                ?? "";
        }

        private sealed class B2CPaymentResult
        {
            public string Gateway { get; set; } = string.Empty;
            public string PaymentMethod { get; set; } = string.Empty;
            public string? ReferenceId { get; set; }
            public decimal PaymentAmount { get; set; }
            public decimal CCFee { get; set; }
            public string? CardType { get; set; }
            public string? Last4 { get; set; }
        }

        private void EmailOrderDetail(int salesId)
        {
            var sales = GetListById(salesId);

            if (sales == null)
                return;

            var timeZone = Uow.Companies.GetAll().FirstOrDefault()?.TimeZone;
            if (sales.SalesDate.HasValue && !string.IsNullOrEmpty(timeZone))
                sales.SalesDate = Utilities.ConvertFromUtcToLocal(sales.SalesDate.Value, timeZone);

            var salesEmail = new SalesDetailDto
            {
                Sales = sales,
                SalesDisplayNumber = SalesDisplayNumber(sales),
                SalesDetails = Uow.Sales.GetSalesDetails(salesId)?.ToList()
            };

            var payee = Uow.Payees.GetById(UserContext.EmpId);

            if (payee != null && !string.IsNullOrEmpty(payee.Email))
            {
                salesEmail.PayeeName = payee.PayeeName;

                string toEmails = payee.Email;
                string subject = "Thank You for Your Order – #" + salesEmail.SalesDisplayNumber;

                string mailBody = _emailService.RenderEmailTemplate("~/Views/Invoice.cshtml", salesEmail);

                EmailSetting setting = _emailSettingService.GetSetting();

                // Customer order confirmation
                _emailAuditService.SendAndLog(new EmailAuditMessage
                {
                    To = toEmails,
                    Subject = subject,
                    HtmlBody = mailBody,
                    EmailCategory = EmailAudit.Category.Document,
                    EmailType = EmailAudit.EmailType.WebOrderConfirmation,
                    PayeeId = payee.PayeeId,
                    DocumentType = EmailAudit.DocumentType.Invoice,
                    DocumentId = salesId,
                    DocumentNumber = salesEmail.SalesDisplayNumber,
                    Source = EmailAudit.Source.System
                });

                subject = "New Order Received – #" + salesEmail.SalesDisplayNumber + " - " + payee.PayeeName;

                // Admin notification
                _emailAuditService.SendAndLog(new EmailAuditMessage
                {
                    To = setting.AdminEmail,
                    Subject = subject,
                    HtmlBody = mailBody,
                    EmailCategory = EmailAudit.Category.Notification,
                    EmailType = EmailAudit.EmailType.WebOrderAdminNotification,
                    DocumentType = EmailAudit.DocumentType.Invoice,
                    DocumentId = salesId,
                    DocumentNumber = salesEmail.SalesDisplayNumber,
                    Source = EmailAudit.Source.System
                });
            }
        }
    }
}
