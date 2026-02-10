using IronPdf;
using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
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

        public SalesService(IUnitOfWork uow,
            IWebHostEnvironment env,
            IDocumentService documentService,
            IEmailSettingService emailSettingService,
            IEmailService emailService) : base(uow)
        {
            _env = env;
            _documentService = documentService;
            _emailSettingService = emailSettingService;
            _emailService = emailService;
        }

        public PagingResponse<SalesList> GetPagedList(SalesListReq salesListReq)
        {
            var sales = Uow.Sales.GetPagedList(salesListReq);

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

        public Sales GetById(int salesId)
        {
            return Uow.Sales.GetById(salesId);
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

                Uow.Sales.Update(sales);
                Uow.Commit();
            }

            return sales;
        }

        public void UpdateInstruction(int salesId, string? instruction)
        {
            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.Instruction, x => instruction)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void UpdatePO(int salesId, string? custPO)
        {
            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.CustPONumber, x => custPO)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void UpdateLoadSeparate(int salesId)
        {
            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
           .SetProperty(x => x.IsLoadSeparate, x => !x.IsLoadSeparate)
           .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public SalesList UpdateCarrier(int salesId, int? shippingCarrierId)
        {
            Uow.Sales.Find(c => c.SalesId == salesId).ExecuteUpdate(setters => setters
           .SetProperty(x => x.ShippingCarrierId, x => shippingCarrierId)
           .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));

            return GetListById(salesId)!;
        }

        public SalesStage UpdateStage(int salesId, int stageId)
        {
            return Uow.Sales.UpdateStage(salesId, stageId);
        }

        public void Delete(int salesId)
        {
            var sales = Uow.Sales.GetById(salesId);

            if (sales != null && !sales.IsLocked)
            {
                Uow.Sales.Find(c => c.SalesId == salesId).ExecuteDelete();
            }
        }

        public ICollection<string?> GetShipRoutes(DateOnly shipDate)
        {
            return Uow.Sales.Find(c => c.ShipDate == shipDate).OrderBy(c => c.ShipRoute).Select(c => c.ShipRoute).Distinct().ToList();
        }

        public void Inject(int salesId)
        {
            Uow.Sales.Inject(salesId);
        }

        public SalesList Checkout(SalesCheckoutReq checkoutReq)
        {
            var salesId = Uow.Sales.Checkout(checkoutReq);

            return GetListById(salesId)!;
        }

        public SalesList UpdatePartially(int salesId)
        {
            Uow.Sales.UpdatePartially(salesId);

            return GetListById(salesId)!;
        }

        public SalesList UpdateNameDate(SalesUpdateReq updateReq)
        {
            Uow.Sales.UpdateNameDate(updateReq);

            return GetListById(updateReq.SalesId)!;
        }

        public SalesList InsertShippingCharge(SalesUpdateReq updateReq)
        {
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

        public void EmailPdf(int salesId)
        {
            var sales = GetById(salesId);

            if (sales == null)
                return;

            var pdfFile = Path.Combine(_env.WebRootPath, "InvoicePdf", sales.SalesNumber + ".pdf");

            if (!IsInvoicePdfExist(sales.SalesNumber))
            {
                pdfFile = _documentService.Invoice(new DocumentReq { SalesId = salesId, SalesNumber = sales.SalesNumber });
            }

            var payee = Uow.Payees.GetById(sales.ShipId.Value);

            if (payee != null && !string.IsNullOrEmpty(payee.EmailInvoice))
            {
                string toEmails = payee.EmailInvoice;
                string subject = "Invoice File";
                string mailbody = "Hi " + payee.PayeeName + ",<br/><br/>Here is a your invoice file for the order#" + sales.SalesNumber + "<br/><br/>";
                string[] attcfiles = [pdfFile];

                var setting = _emailSettingService.GetSetting();

                Task.Factory.StartNew(() => _emailService.SendEmail(setting, toEmails, subject, mailbody, attcfiles), TaskCreationOptions.LongRunning).ContinueWith((t) =>
                {
                    var log = new EmailLog
                    {
                        PayeeId = sales.BillId,
                        Email = toEmails,
                        SentDate = DateTime.Now,
                        EventType = EnumHelper.EmailLogEvent.Invoice.ToString(),
                        ErrorMessage = t.Result,
                        Status = string.IsNullOrEmpty(t.Result)
                    };

                    Uow.EmailLogs.Add(log);
                    Uow.Commit();
                });
            }
        }

        public int MergeOrder(SalesMergeReq mergeReq)
        {
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

            var ids = salesNumbers
                .Split(',', StringSplitOptions.RemoveEmptyEntries)
                .Select(x => x.Trim())
                .Where(x => !string.IsNullOrEmpty(x))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            var docs = new List<PdfDocument>(ids.Count);

            try
            {
                foreach (var salesNum in ids)
                {
                    var pdfPath = Path.Combine(_env.WebRootPath, "InvoicePdf", salesNum + ".pdf");
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

        public void UpdateRoute(List<ShipRouteDetail> routeDetails)
        {
            foreach (var route in routeDetails)
            {
                Uow.Sales.Find(c => c.SalesId == route.SalesId).ExecuteUpdate(setters => setters
                .SetProperty(x => x.ShipRoute, x => route.ShipRoute)
                .SetProperty(x => x.IsLoadSeparate, x => route.IsLoadSeparate)
                .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
            }
        }
    }
}
