using IronPdf;
using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.Reports;
using Microsoft.AspNetCore.Hosting;
using Omu.ValueInjecter;
using Org.BouncyCastle.Ocsp;
using SixLabors.Fonts.Tables.AdvancedTypographic;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection.Emit;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class DocumentService : BaseService, IDocumentService
    {
        private readonly IPDFService _pdfService;
        private readonly IPrintLogService _printLogService;
        private readonly IReportService _reportService;
        private readonly ISalesStageService _salesStageService;
        private readonly ISystemSettingService _systemSettingService;
        private readonly IWebHostEnvironment _env;

        public DocumentService(IUnitOfWork uow,
            IPDFService pdfService,
            IPrintLogService printLogService,
            IReportService reportService,
            ISalesStageService salesStageService,
            ISystemSettingService systemSettingService,
            IWebHostEnvironment env) : base(uow)
        {
            _pdfService = pdfService;
            _printLogService = printLogService;
            _reportService = reportService;
            _salesStageService = salesStageService;
            _systemSettingService = systemSettingService;
            _env = env;
        }

        public string SalesOrder(DocumentReq req)
        {
            if (req?.SalesId is null)
                throw new ArgumentException("SalesId is required.", nameof(req));

            var invoice = _reportService.Invoice(req.SalesId.Value);

            var template = "~/Views/Pdf/SalesOrder.cshtml";
            var html = _pdfService.RenderTemplate(template, invoice);

            var fileName = (invoice.Invoice.DocType == "CM" ? "CreditMemo-" : "SalesOrder-") + invoice.Invoice.SalesNumber + ".pdf";
            string filePath = Path.Combine(_env.WebRootPath, "Pdf", fileName);

            using (var pdf = _pdfService.HtmlToPDF(html))
            {
                _pdfService.AddPageFooter(pdf);

                pdf.SaveAs(filePath);
            }

            return filePath;
        }

        public string PickTicket(DocumentReq req)
        {
            PdfGenerationResult? pdfResult = null;

            try
            {
                if (req?.SalesId is null)
                    throw new ArgumentException("SalesId is required.", nameof(req));

                pdfResult = GeneratePickTicket(req.SalesId.Value, req.IsPrint, true);

                if (req.IsPrint)
                {
                    _printLogService.Create(new PrintLog
                    {
                        DocType = "PickTicket-Single",
                        PrintMode = "S",
                        DocPath = pdfResult.RelativePath,
                        PageCount = pdfResult.Pdf.PageCount,
                    });
                }

                return pdfResult.FullPath;
            }
            finally
            {
                pdfResult?.Pdf?.Dispose();
            }
        }

        public string Invoice(DocumentReq req)
        {
            List<PdfDocument> pdfs = [];
            List<PrintLog> logs = [];

            try
            {
                if (req.SalesId.HasValue)
                {
                    var pdfResult = GenerateInvoice(req.SalesId.Value, req.IsPrint);
                    pdfs.Add(pdfResult.Pdf);

                    logs.Add(new PrintLog
                    {
                        DocType = "Invoice-Single",
                        PrintMode = "S",
                        PageCount = pdfResult.Pdf.PageCount,
                        IsInvoice = true,
                        DocPath = pdfResult.RelativePath,
                        IsBOL = pdfResult.IsBOL
                    });
                }
                else
                {
                    var shipRoutes = Uow.Sales.GetByDateRoute(req.ShipDate.Value, req.ShipRoute)?.ToList();

                    if (shipRoutes == null)
                        throw new KeyNotFoundException("No invoice found for " + req.ShipRoute + " Route");

                    foreach (var sales in shipRoutes)
                    {
                        var pdfResult = GenerateInvoice(sales.SalesId, req.IsPrint);
                        pdfs.Add(pdfResult.Pdf);

                        logs.Add(new PrintLog
                        {
                            DocType = "Invoice-Single",
                            PrintMode = "S",
                            PageCount = pdfResult.Pdf.PageCount,
                            IsInvoice = true,
                            DocPath = pdfResult.RelativePath,
                            IsBOL = pdfResult.IsBOL
                        });
                    }
                }

                if (req.IsPrint && logs.Count > 0)
                    _printLogService.CreateBatch(logs);

                if (pdfs.Count == 0)
                    return null;

                //only for view 
                using var merged = PdfDocument.Merge(pdfs);

                var singleDocPrefix = req.SalesId.HasValue && req.SalesId.Value > 0
                    ? (_reportService.Invoice(req.SalesId.Value).Invoice?.DocType == "CM" ? "CreditMemo" : "Invoice")
                    : "Invoice";
                var suffix = req.SalesId.HasValue ? req.SalesNumber.ToString()
                    : $"{req.ShipDate:MMddyyyy}-{req.ShipRoute}";
                var fileName = $"{singleDocPrefix}-{suffix}.pdf";
                var filePath = Path.Combine(_env.WebRootPath, "Pdf", fileName);

                //_pdfService.AddPageFooter(merged);

                merged.SaveAs(filePath);

                return filePath;
            }
            finally
            {
                // IMPORTANT: dispose everything you created and stored in the list
                foreach (var p in pdfs)
                    p?.Dispose();
            }
        }

        public string PackingList(DocumentReq req)
        {
            if (!req.SalesId.HasValue && !req.ShipDate.HasValue)
                throw new ArgumentException("ShipDate is required when SalesId is not provided.", nameof(req));

            var packing = _reportService.PackingList(req);

            var template = "~/Views/Pdf/PackingList.cshtml";
            var html = _pdfService.RenderTemplate(template, packing);

            var suffix = req.SalesId.HasValue ? req.SalesNumber.ToString()
                   : $"{req.ShipDate:MMddyyyy}-{req.ShipRoute}";

            var fileName = $"PackingList-{suffix}.pdf";
            var relativePath = Path.Combine("Pdf", fileName); // store this in log
            var fullPath = Path.Combine(_env.WebRootPath, relativePath);

            using var pdf = _pdfService.HtmlToPDF(html);

            _pdfService.AddPageFooter(pdf);

            pdf.SaveAs(fullPath);

            if (req.IsPrint)
            {
                _printLogService.Create(new PrintLog
                {
                    DocType = req.SalesId.HasValue ? "PackingList-Single" : "PackingList-ByRoute",
                    PrintMode = req.SalesId.HasValue ? "S" : "B",
                    DocPath = relativePath,
                    PageCount = pdf.PageCount,
                });
            }

            return fullPath;
        }

        public string? LoadingList(DocumentReq req)
        {
            List<PdfDocument> pdfs = [];

            try
            {
                var shipDate = req.ShipDate ?? Uow.Companies.GetNextWorkDate();

                req.ShipDate = shipDate;

                var assignedRoutes = GetAssignedRoutes(shipDate);

                var documentFormat = _systemSettingService.GetByKey<int>(GlobalKey.DOCUMENT_FORMAT);

                if (documentFormat == 1)
                {
                    //1-LoadingList
                    var loading = Uow.Reports.LoadingList(req).ToList();
                    var zones = loading.GroupBy(c => c.Department).ToList();

                    foreach (var zone in zones)
                    {
                        foreach (var route in assignedRoutes)
                        {
                            var grpLoadRoute = zone.Where(c => c.ShipRoute == route.ShipRoute).GroupBy(c => c.LoadRoute).ToList();

                            foreach (var loadRoute in grpLoadRoute)
                            {
                                var routeData = loadRoute.ToList();

                                if (routeData.Count > 0)
                                {
                                    var loadingList = new RptLoadingList
                                    {
                                        LoadingItems = routeData,
                                        TruckNumber = route.TruckNumber,
                                        ShipDate = shipDate,
                                        ShipRoute = loadRoute.Key,
                                        DropCount = GetDropCount(shipDate, route.ShipRoute),
                                    };

                                    var loadtemplate = "~/Views/Pdf/LoadingList.cshtml";
                                    var loadhtml = _pdfService.RenderTemplate(loadtemplate, loadingList);
                                    pdfs.Add(_pdfService.HtmlToPDF(loadhtml));
                                }
                            }
                        }
                    }

                    //2-Packinglist
                    var packingItems = Uow.Reports.PackingList(req).ToList();

                    foreach (var route in assignedRoutes)
                    {
                        var grpLoadRoute = packingItems.Where(c => c.ShipRoute == route.ShipRoute).GroupBy(c => c.LoadRoute).ToList();

                        foreach (var loadRoute in grpLoadRoute)
                        {
                            var routeData = loadRoute.ToList();

                            if (routeData.Count > 0)
                            {
                                var packingStorage = routeData.GroupBy(c => c.StorageName).Select(g => new PackingListStorage
                                {
                                    StorageName = g.Key,
                                    WeightTotal = g.Sum(c => c.ItemWeight),
                                    Products = g.GroupBy(c => new { c.ItemName, c.Comment }).Select(p => new PackingListProduct
                                    {
                                        ItemName = p.Key.ItemName,
                                        Comment = p.Key.Comment,
                                        Items = p.ToList()
                                    }).ToList()
                                }).ToList();

                                var packingList = new RptPackingList
                                {
                                    Storages = packingStorage,
                                    TruckNumber = route.TruckNumber,
                                    ShipDate = shipDate,
                                    ShipRoute = loadRoute.Key,
                                    DropCount = GetDropCount(shipDate, route.ShipRoute)
                                };

                                var packingtemplate = "~/Views/Pdf/PackingList.cshtml";
                                var packinghtml = _pdfService.RenderTemplate(packingtemplate, packingList);
                                pdfs.Add(_pdfService.HtmlToPDF(packinghtml));
                            }
                        }
                    }

                    //3-Harvills
                    var harvills = Uow.Reports.Harvills(shipDate).ToList();
                    var template = "~/Views/Pdf/Harvills.cshtml";
                    var html = _pdfService.RenderTemplate(template, harvills);
                    pdfs.Add(_pdfService.HtmlToPDF(html));

                    //4-StoreTotal
                    var storeTotal = Uow.Reports.StoreTotal(shipDate).ToList();
                    template = "~/Views/Pdf/StoreTotal.cshtml";
                    html = _pdfService.RenderTemplate(template, storeTotal);
                    pdfs.Add(_pdfService.HtmlToPDF(html));

                    //5-Sensitive
                    var sensitive = Uow.Reports.Sensitive(shipDate).ToList();
                    template = "~/Views/Pdf/Sensitive.cshtml";
                    html = _pdfService.RenderTemplate(template, sensitive);
                    pdfs.Add(_pdfService.HtmlToPDF(html));

                    //6-Assign Truck
                    var assignTrucks = Uow.Reports.AssignTruck(shipDate).ToList();
                    template = "~/Views/Pdf/AssignTruck.cshtml";
                    html = _pdfService.RenderTemplate(template, assignTrucks);
                    pdfs.Add(_pdfService.HtmlToPDF(html));
                }
                else
                {
                    var shipRoutes = Uow.Sales.GetByDateRoute(req.ShipDate.Value, req.ShipRoute)?.ToList();

                    foreach (var route in assignedRoutes)
                    {
                        var orders = shipRoutes.Where(c => c.ShipRoute == route.ShipRoute).OrderBy(c => c.RouteOrder).ThenBy(c => c.SalesNumber).ToList();

                        foreach (var order in orders)
                        {
                            var pdfResult = GeneratePickTicket(order.SalesId, req.IsPrint, false);

                            pdfs.Add(pdfResult.Pdf);
                        }
                    }
                }

                if (pdfs.Count == 0)
                    return null;

                var fileName = "Packing-" + shipDate.ToString("MMddyyyy") + ".pdf";
                var relativePath = Path.Combine("Pdf", fileName); // store this in log
                string fullPath = Path.Combine(_env.WebRootPath, relativePath);

                using var merged = PdfDocument.Merge(pdfs);

                _pdfService.AddPageFooter(merged);

                merged.SaveAs(fullPath);

                if (req.IsPrint && merged.PageCount > 0)
                {
                    _printLogService.Create(new PrintLog
                    {
                        DocType = "LoadingList",
                        PrintMode = "B",
                        DocPath = relativePath,
                        PageCount = merged.PageCount,
                    });
                }

                return fullPath;
            }
            finally
            {
                // IMPORTANT: dispose everything you created and stored in the list
                foreach (var p in pdfs)
                    p?.Dispose();
            }
        }

        public string? PackingLabel(DocumentReq req)
        {
            List<PdfDocument> pdfs = [];

            try
            {
                var shipDate = req.ShipDate ?? Uow.Companies.GetNextWorkDate();

                req.ShipDate = shipDate;

                var assignedRoutes = GetAssignedRoutes(shipDate);

                var packingLabels = Uow.Reports.PackingLabel(req).ToList();
                var zones = packingLabels.GroupBy(c => c.Department);
                var tag = 1;

                foreach (var zone in zones)
                {
                    foreach (var route in assignedRoutes)
                    {
                        var labelData = zone.Where(c => c.ShipRoute == route.ShipRoute).ToList();

                        foreach (var item in labelData)
                        {
                            item.Tag = tag;
                            var template = "~/Views/Pdf/PackingLabel.cshtml";
                            var html = _pdfService.RenderTemplate(template, item);
                            pdfs.Add(_pdfService.HtmlToPDF(html));
                            tag += 1;
                        }
                    }
                }

                if (pdfs.Count == 0)
                    return null;

                var fileName = "Label-" + shipDate.ToString("MMddyyyy") + ".pdf";
                var relativePath = Path.Combine("Pdf", fileName); // store this in log
                string fullPath = Path.Combine(_env.WebRootPath, relativePath);

                using var merged = PdfDocument.Merge(pdfs);

                _pdfService.AddPageFooter(merged);

                merged.SaveAs(fullPath);

                if (req.IsPrint && merged.PageCount > 0)
                {
                    var labelPrinterName = _systemSettingService.GetByKey<string>(GlobalKey.LABEL_PRINTER_NAME);

                    merged.Print(labelPrinterName);
                }

                return fullPath;
            }
            finally
            {
                // IMPORTANT: dispose everything you created and stored in the list
                foreach (var p in pdfs)
                    p?.Dispose();
            }
        }

        private int GetDropCount(DateOnly shipDate, string shipRoute)
        {
            return Uow.Sales.Find(c => c.ShipDate == shipDate && c.ShipRoute == shipRoute).Count();
        }

        private List<SalesRoute> GetAssignedRoutes(DateOnly shipDate)
        {
            return Uow.SalesRoutes.Find(c => c.ShipDate == shipDate).OrderBy(s => s.SalesRouteId).ToList();
        }

        private PdfGenerationResult GenerateInvoice(int salesId, bool isPrint)
        {
            List<PdfDocument> pdfs = new();
            bool isBOL = false;

            try
            {
                if (isPrint)
                    _salesStageService.MarkInvoicePrinted(salesId);

                var invoice = _reportService.Invoice(salesId);

                var documentFormat = _systemSettingService.GetByKey<int>(GlobalKey.DOCUMENT_FORMAT);
                var template = documentFormat switch
                {
                    2 => "~/Views/Pdf/Invoice-2.cshtml",
                    3 => "~/Views/Pdf/Invoice-3.cshtml",
                    _ => "~/Views/Pdf/Invoice.cshtml"
                };

                var html = _pdfService.RenderTemplate(template, invoice);
                var pdf = _pdfService.HtmlToPDF(html);
                pdfs.Add(pdf);

                if (invoice.Invoice.ShippingCarrierId.HasValue)
                {
                    template = "~/Views/Pdf/BOL.cshtml";
                    html = _pdfService.RenderTemplate(template, invoice);

                    pdfs.Add(_pdfService.HtmlToPDF(html));
                    isBOL = true;
                }

                var salesNumber = invoice.Invoice.SalesNumber;
                var filePrefix = invoice.Invoice.DocType == "CM" ? "CreditMemo" : "Invoice";
                var fileName = $"{filePrefix}-{salesNumber}.pdf";
                var relativePath = Path.Combine("Pdf", fileName); // store this in DB
                var fullPath = Path.Combine(_env.WebRootPath, relativePath);

                Directory.CreateDirectory(Path.GetDirectoryName(fullPath)!);

                var singlePdf = PdfDocument.Merge(pdfs);
                singlePdf.MetaData.CustomProperties["IsBOL"] = isBOL.ToString();

                _pdfService.AddPageFooter(singlePdf);

                singlePdf.SaveAs(fullPath);

                return new PdfGenerationResult
                {
                    Pdf = singlePdf,
                    RelativePath = relativePath,
                    IsBOL = isBOL
                };
            }
            finally
            {
                // Dispose all intermediate PDFs (invoice part + bol part)
                foreach (var p in pdfs)
                    p?.Dispose();
            }
        }

        private PdfGenerationResult GeneratePickTicket(int salesId, bool isPrint, bool saveToDisk)
        {
            try
            {
                if (isPrint)
                    _salesStageService.MarkPickTicketPrinted(salesId);

                var invoice = _reportService.Invoice(salesId);

                var template = "~/Views/Pdf/PickTicket.cshtml";
                var documentFormat = _systemSettingService.GetByKey<Int32>(GlobalKey.DOCUMENT_FORMAT);
                if (documentFormat == 3)
                    template = "~/Views/Pdf/PickTicket-3.cshtml";

                var html = _pdfService.RenderTemplate(template, invoice);

                var fileName = "PickTicket-" + invoice.Invoice.SalesNumber + ".pdf";
                var relativePath = Path.Combine("Pdf", fileName); // store this in DB
                var fullPath = Path.Combine(_env.WebRootPath, relativePath);

                var pdf = _pdfService.HtmlToPDF(html);

                _pdfService.AddPageFooter(pdf);

                if (saveToDisk)
                    pdf.SaveAs(fullPath);

                return new PdfGenerationResult
                {
                    Pdf = pdf,
                    RelativePath = relativePath,
                    FullPath = fullPath
                };
            }
            catch (Exception ex)
            {
                throw new Exception(ex.Message);
            }
        }
    }
}
