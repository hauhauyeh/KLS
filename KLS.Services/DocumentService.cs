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

                // Route-level print only — bump SalesRoute.PrintCount after the merged
                // file is safely on disk. Per-invoice GenerateInvoice success is NOT
                // enough; Merge or SaveAs above can still throw and leave us with no
                // returnable document, so the increment must sit below SaveAs. Single-
                // invoice prints (req.SalesId.HasValue) never carried PrintCount before
                // this move either — that branch stays uncounted on purpose.
                if (req.IsPrint
                    && !req.SalesId.HasValue
                    && req.ShipDate.HasValue
                    && !string.IsNullOrEmpty(req.ShipRoute))
                {
                    var route = Uow.SalesRoutes
                        .Find(r => r.ShipDate == req.ShipDate.Value && r.ShipRoute == req.ShipRoute)
                        .FirstOrDefault();
                    if (route != null)
                    {
                        route.PrintCount = (route.PrintCount ?? 0) + 1;
                        Uow.SalesRoutes.Update(route);
                        Uow.Commit();
                    }
                }

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

        public string? TotalList(DocumentReq req)
        {
            List<PdfDocument> pdfs = [];

            try
            {
                // TotalList intentionally reuses the same route-packing builder as the
                // LoadingList packing section so both documents stay identical.
                var shipDate = req.ShipDate ?? Uow.Companies.GetNextWorkDate();
                req.ShipDate = shipDate;

                var assignedRoutes = GetAssignedRoutes(shipDate);
                var packingItems = Uow.Reports.PackingList(req).ToList();

                AppendRoutePackingListPdfs(
                    pdfs,
                    packingItems,
                    assignedRoutes,
                    shipDate,
                    req.ShipRoute);

                if (pdfs.Count == 0)
                    return null;

                var suffix = string.IsNullOrWhiteSpace(req.ShipRoute)
                    ? shipDate.ToString("MMddyyyy")
                    : $"{shipDate:MMddyyyy}-{req.ShipRoute}";
                var fileName = $"TotalList-{suffix}.pdf";
                var relativePath = Path.Combine("Pdf", fileName);
                var fullPath = Path.Combine(_env.WebRootPath, relativePath);

                using var merged = PdfDocument.Merge(pdfs);

                _pdfService.AddPageFooter(merged);
                merged.SaveAs(fullPath);

                if (req.IsPrint && merged.PageCount > 0)
                {
                    _printLogService.Create(new PrintLog
                    {
                        DocType = "TotalList",
                        PrintMode = string.IsNullOrWhiteSpace(req.ShipRoute) ? "B" : "S",
                        DocPath = relativePath,
                        PageCount = merged.PageCount,
                    });
                }

                return fullPath;
            }
            finally
            {
                foreach (var p in pdfs)
                    p?.Dispose();
            }
        }

        public string? TotalSplitList(DocumentReq req)
        {
            if (!req.ShipDate.HasValue && !req.SalesId.HasValue)
                throw new ArgumentException("ShipDate is required when SalesId is not provided.", nameof(req));

            // TotalSplit is a new standalone route report: same raw packing rows,
            // but a different outer-box grouping rule for lbs rows across sales.
            var packing = _reportService.TotalSplitPacking(req);
            var template = "~/Views/Pdf/PackingList.cshtml";
            var html = _pdfService.RenderTemplate(template, packing);

            var suffix = req.SalesId.HasValue ? req.SalesNumber.ToString()
                   : $"{req.ShipDate:MMddyyyy}-{req.ShipRoute}";

            var fileName = $"TotalSplit-{suffix}.pdf";
            var relativePath = Path.Combine("Pdf", fileName);
            var fullPath = Path.Combine(_env.WebRootPath, relativePath);

            using var pdf = _pdfService.HtmlToPDF(html);

            _pdfService.AddPageFooter(pdf);
            pdf.SaveAs(fullPath);

            if (req.IsPrint)
            {
                _printLogService.Create(new PrintLog
                {
                    DocType = req.SalesId.HasValue ? "TotalSplitList-Single" : "TotalSplitList-ByRoute",
                    PrintMode = req.SalesId.HasValue ? "S" : "B",
                    DocPath = relativePath,
                    PageCount = pdf.PageCount,
                });
            }

            return fullPath;
        }

        public string? HarvillsList(DocumentReq req)
        {
            var shipDate = req.ShipDate ?? Uow.Companies.GetNextWorkDate();

            // Standalone Harvills now uses the same packing-style view model and template
            // as PackingList, but keeps its own filtered source rows/title.
            var report = _reportService.HarvillsPacking(shipDate);
            var template = "~/Views/Pdf/PackingList.cshtml";
            var html = _pdfService.RenderTemplate(template, report);

            var fileName = $"Harvills-{shipDate:MMddyyyy}.pdf";
            var relativePath = Path.Combine("Pdf", fileName);
            var fullPath = Path.Combine(_env.WebRootPath, relativePath);

            using var pdf = _pdfService.HtmlToPDF(html);

            _pdfService.AddPageFooter(pdf);
            pdf.SaveAs(fullPath);

            return fullPath;
        }

        public string? StoreTotalList(DocumentReq req)
        {
            var shipDate = req.ShipDate ?? Uow.Companies.GetNextWorkDate();

            // Standalone Store Total also uses the packing-style layout, with only the
            // filtered source rows/title differing from Harvills.
            var report = _reportService.StoreTotalPacking(shipDate);
            var template = "~/Views/Pdf/PackingList.cshtml";
            var html = _pdfService.RenderTemplate(template, report);

            var fileName = $"StoreTotal-{shipDate:MMddyyyy}.pdf";
            var relativePath = Path.Combine("Pdf", fileName);
            var fullPath = Path.Combine(_env.WebRootPath, relativePath);

            using var pdf = _pdfService.HtmlToPDF(html);

            _pdfService.AddPageFooter(pdf);
            pdf.SaveAs(fullPath);

            return fullPath;
        }

        public string? LoadingList(DocumentReq req)
        {
            List<PdfDocument> pdfs = [];

            try
            {
                var shipDate = req.ShipDate ?? Uow.Companies.GetNextWorkDate();

                req.ShipDate = shipDate;

                EnsureAssignedRouteRequired(shipDate, req.ShipRoute, "Loading List");

                var assignedRoutes = GetAssignedRoutes(shipDate);

                var documentFormat = _systemSettingService.GetByKey<int>(GlobalKey.DOCUMENT_FORMAT);

                if (documentFormat == 1)
                {
                    //1-LoadingList
                    AppendLoadingListSectionPdfs(pdfs, req, assignedRoutes, shipDate);

                    //2-Packinglist
                    var packingItems = Uow.Reports.PackingList(req).ToList();

                    // Keep LoadingList packing pages on the same shared builder used by
                    // standalone TotalList so the two outputs cannot drift again.
                    AppendRoutePackingListPdfs(
                        pdfs,
                        packingItems,
                        assignedRoutes,
                        shipDate);

                    //3-Harvills
                    // Reuse the standalone PackingList layout so Harvills becomes a
                    // filtered packing-style report instead of the old legacy layout.
                    var harvills = _reportService.HarvillsPacking(shipDate);
                    var template = "~/Views/Pdf/PackingList.cshtml";
                    var html = _pdfService.RenderTemplate(template, harvills);
                    pdfs.Add(_pdfService.HtmlToPDF(html));

                    //4-StoreTotal
                    // Reuse the same packing-style layout here too, with only the
                    // StoreTotal source filter differing from Harvills.
                    var storeTotal = _reportService.StoreTotalPacking(shipDate);
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

        public string? RouteLoadingList(DocumentReq req)
        {
            List<PdfDocument> pdfs = [];

            try
            {
                if (string.IsNullOrWhiteSpace(req.ShipRoute))
                    throw new ArgumentException("ShipRoute is required for route loading list.", nameof(req));

                var shipDate = req.ShipDate ?? Uow.Companies.GetNextWorkDate();

                req.ShipDate = shipDate;

                EnsureAssignedRouteRequired(shipDate, req.ShipRoute, "Loading List");

                var assignedRoutes = GetAssignedRoutes(shipDate);

                // RouteLoadingList intentionally renders only the loading-list section
                // from the bundled LoadingList document. It does not append packing,
                // Harvills, StoreTotal, Sensitive, or Assign Truck pages.
                AppendLoadingListSectionPdfs(pdfs, req, assignedRoutes, shipDate, req.ShipRoute);

                if (pdfs.Count == 0)
                    return null;

                var fileName = $"LoadingList-{shipDate:MMddyyyy}-{req.ShipRoute}.pdf";
                var relativePath = Path.Combine("Pdf", fileName);
                string fullPath = Path.Combine(_env.WebRootPath, relativePath);

                using var merged = PdfDocument.Merge(pdfs);

                _pdfService.AddPageFooter(merged);

                merged.SaveAs(fullPath);

                return fullPath;
            }
            finally
            {
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

                EnsureAssignedRouteRequired(shipDate, req.ShipRoute, "Packing Label");

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
                            pdfs.Add(_pdfService.HtmlToPDF(html, true));
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

                //_pdfService.AddPageFooter(merged);

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

        // Loading List and Packing Label depend on formal SalesRoute assignment data.
        // Keep a backend guard so direct API calls still get a clear message instead of
        // silently producing empty output when Assign Truck has not been done yet.
        private void EnsureAssignedRouteRequired(DateOnly shipDate, string? shipRoute, string documentName)
        {
            var assignedRoutes = GetAssignedRoutes(shipDate);
            var hasAssignedRoute = string.IsNullOrWhiteSpace(shipRoute)
                ? assignedRoutes.Count > 0
                : assignedRoutes.Any(r => r.ShipRoute == shipRoute);

            if (!hasAssignedRoute)
                throw new InvalidOperationException($"{documentName} requires Assign Truck first for the selected date/route.");
        }

        // This shared builder is the single source of truth for the loading-list
        // section shown inside bundled LoadingList and the route-only LoadingList.
        private void AppendLoadingListSectionPdfs(
            List<PdfDocument> pdfs,
            DocumentReq req,
            List<SalesRoute> assignedRoutes,
            DateOnly shipDate,
            string? shipRouteFilter = null)
        {
            var loading = Uow.Reports.LoadingList(req).ToList();
            var routesToRender = string.IsNullOrWhiteSpace(shipRouteFilter)
                ? assignedRoutes
                : assignedRoutes.Where(r => r.ShipRoute == shipRouteFilter).ToList();
            var zones = loading.GroupBy(c => c.Department).ToList();

            foreach (var zone in zones)
            {
                foreach (var route in routesToRender)
                {
                    var grpLoadRoute = zone.Where(c => c.ShipRoute == route.ShipRoute).GroupBy(c => c.LoadRoute).ToList();

                    foreach (var loadRoute in grpLoadRoute)
                    {
                        var routeData = loadRoute.ToList();

                        if (routeData.Count == 0)
                            continue;

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

        // This shared builder is the single source of truth for the route packing pages
        // shown inside LoadingList and the new standalone TotalList.
        private void AppendRoutePackingListPdfs(
            List<PdfDocument> pdfs,
            List<RptPackingItem> packingItems,
            List<SalesRoute> assignedRoutes,
            DateOnly shipDate,
            string? shipRouteFilter = null)
        {
            var routesToRender = string.IsNullOrWhiteSpace(shipRouteFilter)
                ? assignedRoutes
                : assignedRoutes.Where(r => r.ShipRoute == shipRouteFilter).ToList();

            // Some route documents can exist before a SalesRoute assignment row is created.
            // When a specific route was requested and packing data exists, fall back to a
            // synthetic route shell so TotalList still renders instead of returning null.
            if (!string.IsNullOrWhiteSpace(shipRouteFilter) && routesToRender.Count == 0)
            {
                var hasPackingRows = packingItems.Any(c => c.ShipRoute == shipRouteFilter);
                if (hasPackingRows)
                {
                    routesToRender =
                    [
                        new SalesRoute
                        {
                            ShipDate = shipDate,
                            ShipRoute = shipRouteFilter
                        }
                    ];
                }
            }

            foreach (var route in routesToRender)
            {
                var grpLoadRoute = packingItems
                    .Where(c => c.ShipRoute == route.ShipRoute)
                    .GroupBy(c => c.LoadRoute)
                    .ToList();

                foreach (var loadRoute in grpLoadRoute)
                {
                    var routeData = loadRoute.ToList();

                    if (routeData.Count == 0)
                        continue;

                    var packingList = BuildRoutePackingList(routeData, route, shipDate, loadRoute.Key);
                    var packingtemplate = "~/Views/Pdf/PackingList.cshtml";
                    var packinghtml = _pdfService.RenderTemplate(packingtemplate, packingList);
                    pdfs.Add(_pdfService.HtmlToPDF(packinghtml));
                }
            }
        }

        // TotalList / LoadingList route packing now follows the same clarified section
        // rules as the standalone packing reports:
        // 1. SQL classifies original Cooler rows into Cooler (cs/lbs) or Prepack
        //    (other units).
        // 2. Prepack shows one combined unit total plus indented customer detail.
        // 3. Cooler lbs can still split into separate outer boxes when identical
        //    item/qty/comment rows come from different sales.
        private RptPackingList BuildRoutePackingList(
            List<RptPackingItem> routeData,
            SalesRoute route,
            DateOnly shipDate,
            string? loadRouteKey)
        {
            var packingStorage = routeData
                .GroupBy(c => c.StorageName)
                .OrderBy(g => GetPackingStorageSortOrder(g.Key))
                .ThenBy(g => g.Key)
                .Select(g => new PackingListStorage
                {
                    StorageName = g.Key,
                    WeightTotal = g.Sum(c => c.ItemWeight),
                    Products = BuildRoutePackingProducts(g)
                })
                .ToList();

            return new RptPackingList
            {
                Storages = packingStorage,
                TruckNumber = route.TruckNumber,
                ShipDate = shipDate,
                ShipRoute = loadRouteKey,
                DropCount = GetDropCount(shipDate, route.ShipRoute)
            };
        }

        private static List<PackingListProduct> BuildRoutePackingProducts(
            IGrouping<string?, RptPackingItem> storageGroup)
        {
            if (string.Equals(storageGroup.Key, "Prepack", StringComparison.OrdinalIgnoreCase))
            {
                return storageGroup
                    .GroupBy(c => new { c.ItemName, c.Comment })
                    .Select(p => new PackingListProduct
                    {
                        ItemName = p.Key.ItemName,
                        Comment = p.Key.Comment,
                        UnitLines = BuildRoutePrepackUnitLines(p)
                    })
                    .ToList();
            }

            return storageGroup
                .GroupBy(c => ResolvePackingProductGroupKey(c, storageGroup))
                .Select(p => new PackingListProduct
                {
                    ItemName = p.Key.ItemName,
                    Comment = p.Key.Comment,
                    Subtitle = p.Key.Subtitle,
                    Items = AggregatePackingProductItems(p)
                })
                .ToList();
        }

        private static int GetPackingStorageSortOrder(string? storageName)
        {
            if (string.Equals(storageName, "Cooler", StringComparison.OrdinalIgnoreCase))
                return 0;

            if (string.Equals(storageName, "Prepack", StringComparison.OrdinalIgnoreCase))
                return 1;

            if (string.Equals(storageName, "Freezer", StringComparison.OrdinalIgnoreCase))
                return 2;

            if (string.Equals(storageName, "Warehouse", StringComparison.OrdinalIgnoreCase))
                return 3;

            if (string.Equals(storageName, "Driver", StringComparison.OrdinalIgnoreCase))
                return 4;

            if (string.Equals(storageName, "Store", StringComparison.OrdinalIgnoreCase))
                return 5;

            if (string.Equals(storageName, "Customer", StringComparison.OrdinalIgnoreCase))
                return 6;

            return 99;
        }

        // Default behavior keeps the historical product box merge:
        // ItemName + Comment.
        //
        // Cooler lbs exception:
        // If another lbs row in the same Cooler section would look identical on the page
        // (same item, comment, qty, unit) but comes from a different sale, split the
        // product box by SalesNumber and show a small customer subtitle.
        private static PackingProductGroupKey ResolvePackingProductGroupKey(
            RptPackingItem item,
            IGrouping<string?, RptPackingItem> storageGroup)
        {
            if (!string.Equals(storageGroup.Key, "Cooler", StringComparison.OrdinalIgnoreCase)
                || !string.Equals(item.Unit, "lbs", StringComparison.OrdinalIgnoreCase))
            {
                return new PackingProductGroupKey(item.ItemName, item.Comment, null, null);
            }

            var normalizedComment = NormalizePackingComment(item.Comment);
            var hasVisualCollisionAcrossSales = storageGroup.Any(x =>
                string.Equals(x.Unit, "lbs", StringComparison.OrdinalIgnoreCase)
                && string.Equals(x.ItemName, item.ItemName, StringComparison.OrdinalIgnoreCase)
                && string.Equals(NormalizePackingComment(x.Comment), normalizedComment, StringComparison.OrdinalIgnoreCase)
                && x.ShipQty == item.ShipQty
                && !string.Equals(x.SalesNumber, item.SalesNumber, StringComparison.OrdinalIgnoreCase));

            if (!hasVisualCollisionAcrossSales)
            {
                return new PackingProductGroupKey(item.ItemName, item.Comment, null, null);
            }

            return new PackingProductGroupKey(item.ItemName, item.Comment, item.SalesNumber, item.PayeeName);
        }

        // Route packing uses the same nested Prepack layout: one unit total line,
        // then customer split detail when the same non-cs/non-lbs unit comes from
        // multiple source sales.
        private static List<PackingListUnitLine> BuildRoutePrepackUnitLines(
            IEnumerable<RptPackingItem> productItems)
        {
            return productItems
                .Where(x => x.ShipQty != null && !string.IsNullOrWhiteSpace(x.Unit))
                .GroupBy(x => x.Unit)
                .OrderBy(g => g.Key)
                .SelectMany(g =>
                {
                    var lines = new List<PackingListUnitLine>
                    {
                        new PackingListUnitLine
                        {
                            ShipQty = g.Sum(x => x.ShipQty) ?? 0,
                            Unit = g.Key,
                            IsSplitDetail = false
                        }
                    };

                    if (!string.Equals(g.Key, "cs", StringComparison.OrdinalIgnoreCase)
                        && !string.Equals(g.Key, "lbs", StringComparison.OrdinalIgnoreCase))
                    {
                        var salesSplits = g
                            .GroupBy(x => new { x.SalesNumber, x.PayeeName })
                            .Where(x => !string.IsNullOrWhiteSpace(x.Key.SalesNumber))
                            .OrderBy(x => x.Key.PayeeName)
                            .ThenBy(x => x.Key.SalesNumber)
                            .ToList();

                        if (salesSplits.Count > 1)
                        {
                            lines.AddRange(salesSplits.Select(x => new PackingListUnitLine
                            {
                                ShipQty = x.Sum(y => y.ShipQty) ?? 0,
                                Unit = g.Key,
                                IsSplitDetail = true,
                                Subtitle = x.Key.PayeeName
                            }));
                        }
                    }

                    return lines;
                })
                .ToList();
        }

        private static string NormalizePackingComment(string? comment)
            => string.IsNullOrWhiteSpace(comment) ? string.Empty : comment.Trim();

        // PackingList.cshtml renders one visible line from:
        // Qty + Unit + AisleBay.
        // Aggregate to that same display shape so a normal combined product box shows
        // total qty again, while lbs-only split boxes still remain separate.
        private static List<RptPackingItem> AggregatePackingProductItems(
            IEnumerable<RptPackingItem> productItems)
        {
            var itemList = productItems.ToList();

            // Customer marker rows do not represent a measurable qty/unit line.
            // Keep them untouched so the report does not render a fake "0" qty.
            if (itemList.All(x => x.ShipQty == null && string.IsNullOrWhiteSpace(x.Unit)))
            {
                return itemList;
            }

            return itemList
                .GroupBy(x => new
                {
                    x.Unit,
                    x.Aisle,
                    x.Bay
                })
                .Select(g =>
                {
                    var first = g.First();
                    return new RptPackingItem
                    {
                        Id = first.Id,
                        StorageName = first.StorageName,
                        ItemName = first.ItemName,
                        ItemName2 = first.ItemName2,
                        Unit = first.Unit,
                        ShipQty = g.Sum(x => x.ShipQty) ?? 0,
                        Comment = first.Comment,
                        ShipRoute = first.ShipRoute,
                        LoadRoute = first.LoadRoute,
                        SalesNumber = first.SalesNumber,
                        PayeeName = first.PayeeName,
                        ItemWeight = g.Sum(x => x.ItemWeight) ?? 0,
                        Aisle = first.Aisle,
                        Bay = first.Bay
                    };
                })
                .ToList();
        }

        // Internal helper key for TotalList / LoadingList packing boxes.
        private sealed record PackingProductGroupKey(string? ItemName, string? Comment, string? SplitKey, string? Subtitle);

        private List<SalesRoute> GetAssignedRoutes(DateOnly shipDate)
        {
            return Uow.SalesRoutes.Find(c => c.ShipDate == shipDate)
                .OrderBy(s => s.TruckRouteOrder ?? int.MaxValue)
                .ThenBy(s => s.SalesRouteId)
                .ToList();
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

        public string Check(int vendorPaymentId)
        {
            var check = _reportService.CheckPrint(vendorPaymentId);
            if (check == null)
                throw new Exception("Check not found.");
            if (check.PaymentMethod != "CHECK")
                throw new Exception("You can only print computer generated check.");

            var billDetails = _reportService.CheckPrintDetail(vendorPaymentId).ToList();

            var accountCode = Uow.Accounts.GetById(check.FromAccountId)?.AccountCode ?? "";
            var logoPath = Path.Combine(_env.WebRootPath, "logo", accountCode.Replace("@", "") + "-logo.jpg");
            var bankLogo = new Uri(logoPath).AbsoluteUri;

            var amtInWords = Utilities.CurrencyToWords(check.PaymentAmount);

            var pmt = new RptCheckPayment
            {
                VendorInfo = check,
                BillDetails = billDetails,
                BankLogo = bankLogo,
                AmtInWords = amtInWords
            };

            var template = "~/Views/Pdf/Check.cshtml";
            var html = _pdfService.RenderTemplate(template, pmt);

            var relativePath = Path.Combine("Pdf", $"Check-{vendorPaymentId}.pdf");
            string fullPath = Path.Combine(_env.WebRootPath, relativePath);
            using (var pdf = _pdfService.HtmlToPDF(html))
            {
                pdf.SaveAs(fullPath);
            }

            _printLogService.Create(new PrintLog
            {
                DocType = "Check",
                PrintMode = "S",
                DocPath = relativePath,
                PageCount = 1
            });

            var vendorPayment = Uow.VendorPayments.GetById(vendorPaymentId);

            if (vendorPayment != null)
            {
                vendorPayment.PrintDate = DateOnly.FromDateTime(DateTime.Now);
                vendorPayment.UpdatedAt = DateTime.UtcNow;

                if (!vendorPayment.MailDate.HasValue)
                    vendorPayment.MailDate = vendorPayment.PrintDate;

                Uow.VendorPayments.Update(vendorPayment);
                Uow.Commit();
            }

            return fullPath;
        }

        public string SalesQuote(int salesQuoteId)
        {
            var report = _reportService.SalesQuote(salesQuoteId);

            var template = "~/Views/Pdf/SalesQuote.cshtml";
            var html = _pdfService.RenderTemplate(template, report);

            var fileName = "SalesQuote-" + report.Quote!.QuoteNumber + ".pdf";
            string filePath = Path.Combine(_env.WebRootPath, "Pdf", fileName);

            using (var pdf = _pdfService.HtmlToPDF(html))
            {
                _pdfService.AddPageFooter(pdf);
                pdf.SaveAs(filePath);
            }

            return filePath;
        }
    }
}
