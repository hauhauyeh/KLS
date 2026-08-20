using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Models.Reports;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class ReportService : BaseService, IReportService
    {
        private static readonly HashSet<string> GusPOInventoryStatusCat0 = new(StringComparer.OrdinalIgnoreCase)
        {
            "Stretch Film",
            "Tape",
            "Label",
            "To Go Box"
        };

        private static readonly HashSet<string> GusPOInventoryStatusExcludedCat1 = new(StringComparer.OrdinalIgnoreCase)
        {
            "Pre-Stretched Wrap"
        };

        private readonly ICompanyService _companyService;
        private readonly ISystemSettingService _systemSettingService;
        private readonly ISalesRouteService _salesRouteService;
        private readonly ISalesRouteDetailService _salesRouteDetailService;

        public ReportService(IUnitOfWork uow,
            ICompanyService companyService,
            ISystemSettingService systemSettingService,
            ISalesRouteService salesRouteService,
            ISalesRouteDetailService salesRouteDetailService) : base(uow)
        {
            _companyService = companyService;
            _systemSettingService = systemSettingService;
            _salesRouteService = salesRouteService;
            _salesRouteDetailService = salesRouteDetailService;
        }

        public RptInvoice Invoice(int salesId)
        {
            var invoice = Uow.Reports.Invoice(salesId);

            return new RptInvoice
            {
                Invoice = Uow.Reports.Invoice(salesId),
                InvoiceDetails = Uow.Reports.InvoiceDetail(salesId)?.ToList(),
                Statement = CustStmt(invoice.ShipId),
                Company = _companyService.GetDefault(),
                HasDiscount = _systemSettingService.GetByKey<Boolean>(GlobalKey.SYSTEM_HAS_DISCOUNT),
                UseSalesDocNumber = _systemSettingService.GetByKey<Boolean>(GlobalKey.SALES_DOC_NUMBER_DISPLAY_ENABLED),
                PriceDecimals = _systemSettingService.GetPriceDecimals(),
                //Promotions = _PromotionManager.GetDisplay(),
            };
        }

        public RptSalesQuote SalesQuote(int salesQuoteId)
        {
            var quote = Uow.SalesQuotes.GetById(salesQuoteId);
            var customer = Uow.Payees.GetById(quote.PayeeId);
            string? salesRepName = null;
            if (quote.SalesRepId.HasValue)
            {
                var rep = Uow.Payees.GetById(quote.SalesRepId.Value);
                salesRepName = rep?.PayeeName;
            }

            return new RptSalesQuote
            {
                Quote = quote,
                Details = Uow.Reports.SalesQuoteDetail(salesQuoteId)?.ToList(),
                Customer = customer,
                SalesRepName = salesRepName,
                Company = _companyService.GetDefault(),
                PriceDecimals = _systemSettingService.GetPriceDecimals(),
            };
        }

        public RptVendStmt VendStmt(int payeeId)
        {
            return Uow.Reports.VendStmt(payeeId);
        }

        public RptCustStmt CustStmt(int payeeId, StatementScope scope = StatementScope.ShipTo)
        {
            return Uow.Reports.CustStmt(payeeId, scope);

            //var details = Uow.Sales.Find(s => s.ShipId == payeeId && s.AmountDue != 0)
            //    .GroupBy(s => new { s.ShipDate.Value.Year, s.ShipDate.Value.Month })
            //    .Select(g => new RptCustStmtDetail
            //    {
            //        ShipMonth = new DateTimeFormatInfo().GetMonthName(g.Key.Month) + " - " + g.Key.Year.ToString(),
            //        Sales = g.OrderBy(s => s.ShipDate).ToList()
            //    }).ToList();

            //var customer = Uow.Customers.GetById(payeeId);

            //return new RptCustStmt
            //{
            //    Details = details,
            //    Payee = Uow.Payees.GetById(payeeId),
            //    IsPromotionEnabled = customer.IsPromotionEnabled,
            //    AvailableCredit = Uow.CustomerPayments.Find(c => c.PayeeId == payeeId && c.UnappliedAmount != 0 && c.IsReturned == false).ToList()
            //};
        }

        public RptPackingList PackingList(DocumentReq req)
        {
            var packingItems = Uow.Reports.PackingList(req).ToList();
            return BuildStandalonePackingReport(packingItems, req);
        }

        public RptPackingList TotalSplitPacking(DocumentReq req)
        {
            // TotalSplit reuses the same raw packing rows as standalone PackingList.
            // With the newer zone split, Prepack gets nested customer detail while
            // Cooler can still use the lbs-only outer split rule.
            var packingItems = Uow.Reports.PackingList(req).ToList();

            return BuildStandalonePackingReport(
                packingItems,
                req,
                reportTitle: "Total Split",
                useLbsOuterSplit: true,
                useWeightLikeOuterSplit: false,
                bypassCoolerStorageNameCheck: false,
                useUnitSplitAcrossAllStorages: false);
        }

        public RptPackingList HarvillsPacking(DateOnly shipDate)
        {
            // Harvills now follows a simpler grouped-total rule:
            // 1. Keep the SQL section order driven by ItemStorage.SortOrder.
            // 2. Group rows inside each section by ItemId + Unit + Comment.
            // 3. Show one grouped total qty/unit line per item group.
            var rows = Uow.Reports.Harvills(shipDate).ToList();

            var storages = rows
                .GroupBy(x => x.Section)
                .Select(g => new PackingListStorage
                {
                    StorageName = g.Key,
                    Products = g
                        .GroupBy(x => new { x.ItemId, x.Unit, x.Comment })
                        .OrderBy(p => p.First().ItemName)
                        .ThenBy(p => p.Key.Comment)
                        .ThenBy(p => p.Key.Unit)
                        .Select(p => new PackingListProduct
                        {
                            ItemName = p.First().ItemName,
                            Comment = p.Key.Comment,
                            UnitLines = BuildHarvillsUnitLines(p)
                        })
                        .ToList()
                })
                .ToList();

            return new RptPackingList
            {
                ReportTitle = "Harvills",
                ShipDate = shipDate,
                Storages = storages
            };
        }

        public RptPackingList StoreTotalPacking(DateOnly shipDate)
        {
            // Store Total follows its own simpler print rule:
            // 1. Group rows by ItemId + Unit + Comment inside each section.
            // 2. Show one grouped total qty/unit line first.
            // 3. Show one payee detail line under that grouped total for each source row.
            //
            // This report no longer tries to imitate TotalSplit outer-box behavior.
            // The SQL already limits the scope to cooler rows and excludes cs/lbs.
            var rows = Uow.Reports.StoreTotal(shipDate).ToList();

            var storages = rows
                .GroupBy(x => x.Section)
                .Select(g => new PackingListStorage
                {
                    StorageName = g.Key,
                    Products = g
                        .GroupBy(x => new { x.ItemId, x.Unit, x.Comment })
                        .OrderBy(p => p.First().ItemName)
                        .ThenBy(p => p.Key.Comment)
                        .ThenBy(p => p.Key.Unit)
                        .Select(p => new PackingListProduct
                        {
                            ItemName = p.First().ItemName,
                            Comment = p.Key.Comment,
                            UnitLines = BuildStoreTotalUnitLines(p)
                        })
                        .ToList()
                })
                .ToList();

            return new RptPackingList
            {
                ReportTitle = "Store Total",
                ShipDate = shipDate,
                Storages = storages
            };
        }

        // Standalone packing-style reports share the same header and inside-box qty
        // aggregation. The only variable here is whether lbs rows can split the
        // outer product box by source sale.
        private RptPackingList BuildStandalonePackingReport(
            List<RptPackingItem> packingItems,
            DocumentReq req,
            string? reportTitle = null,
            bool useLbsOuterSplit = false,
            bool useWeightLikeOuterSplit = false,
            bool bypassCoolerStorageNameCheck = false,
            bool useUnitSplitAcrossAllStorages = false)
        {
            var payeeName = "";

            if (req.SalesId.HasValue)
            {
                var sales = Uow.Sales.GetById(req.SalesId.Value);
                payeeName = Uow.Payees.GetById(sales.ShipId.Value)?.PayeeName;
                req.ShipDate = sales.ShipDate;
                req.ShipRoute = sales.ShipRoute;
            }

            return BuildPackingListReport(
                packingItems,
                req.ShipDate,
                req.ShipRoute,
                req.SalesId,
                payeeName,
                _salesRouteService.GetByDateRoute(req.ShipDate, req.ShipRoute)?.TruckNumber,
                reportTitle,
                useLbsOuterSplit,
                useWeightLikeOuterSplit,
                bypassCoolerStorageNameCheck,
                useUnitSplitAcrossAllStorages);
        }

        // PackingList.cshtml renders one visible line from Qty + Unit + AisleBay.
        // Aggregate to that same display shape so the standalone PackingList totals
        // inside-box qty lines again without changing the outer box split behavior.
        private static List<RptPackingItem> AggregatePackingProductItems(
            IEnumerable<RptPackingItem> productItems)
        {
            var itemList = productItems.ToList();

            // Customer marker rows do not represent measurable qty/unit lines.
            // Keep them untouched so no fake "0" row is introduced.
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

        // Prepack keeps one outer item box per item/comment. Inside that box,
        // combine by unit first (cs first, then other units). For the secondary
        // non-cs/non-lbs unit total, show indented customer split detail when
        // multiple source sales contribute to that same unit line.
        private static List<PackingListUnitLine> BuildPrepackUnitLines(
            IEnumerable<RptPackingItem> productItems)
        {
            return productItems
                .Where(x => x.ShipQty != null && !string.IsNullOrWhiteSpace(x.Unit))
                .GroupBy(x => x.Unit)
                .OrderBy(g => string.Equals(g.Key, "cs", StringComparison.OrdinalIgnoreCase) ? 0 : 1)
                .ThenBy(g => g.Key)
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

                    // Prepack contains non-cs/non-lbs units. Keep one combined unit
                    // line first, then show customer split detail only when more than
                    // one source sale contributes to that same unit total.
                    if (!string.Equals(g.Key, "cs", StringComparison.OrdinalIgnoreCase)
                        && !IsWeightLikeUnit(g.Key))
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

        // Store Total prints one grouped total qty/unit line, then the payee detail
        // rows under it. Grouping is decided earlier by ItemId + Unit + Comment.
        private static List<PackingListUnitLine> BuildStoreTotalUnitLines(
            IEnumerable<RptStoreTotalItem> productItems)
        {
            var itemList = productItems.ToList();
            var first = itemList.First();

            var lines = new List<PackingListUnitLine>
            {
                new PackingListUnitLine
                {
                    ShipQty = itemList.Sum(x => x.ShipQty) ?? 0,
                    Unit = first.Unit,
                    IsSplitDetail = false
                }
            };

            lines.AddRange(itemList
                .OrderBy(x => x.PayeeName)
                .ThenBy(x => x.SalesNumber)
                .Select(x => new PackingListUnitLine
                {
                    ShipQty = x.ShipQty ?? 0,
                    Unit = x.Unit,
                    IsSplitDetail = true,
                    Subtitle = x.PayeeName
                }));

            return lines;
        }

        // Harvills shows only one grouped total line per ItemId + Unit + Comment.
        private static List<PackingListUnitLine> BuildHarvillsUnitLines(
            IEnumerable<RptHarvillsItem> productItems)
        {
            var itemList = productItems.ToList();
            var first = itemList.First();

            return new List<PackingListUnitLine>
            {
                new PackingListUnitLine
                {
                    ShipQty = itemList.Sum(x => x.ShipQty) ?? 0,
                    Unit = first.Unit,
                    IsSplitDetail = false
                }
            };
        }

        private static List<PackingListProduct> BuildPackingProducts(
            IGrouping<string?, RptPackingItem> storageGroup,
            bool useLbsOuterSplit,
            bool useWeightLikeOuterSplit,
            bool bypassCoolerStorageNameCheck,
            bool useUnitSplitAcrossAllStorages)
        {
            if (useUnitSplitAcrossAllStorages || string.Equals(storageGroup.Key, "Prepack", StringComparison.OrdinalIgnoreCase))
            {
                return storageGroup
                    .GroupBy(c => new { c.ItemName, c.Comment })
                    .Select(p => new PackingListProduct
                    {
                        ItemName = p.Key.ItemName,
                        Comment = p.Key.Comment,
                        UnitLines = BuildPrepackUnitLines(p)
                    })
                    .ToList();
            }

            return storageGroup
                .GroupBy(c => ResolvePackingProductGroupKey(c, storageGroup, useLbsOuterSplit, useWeightLikeOuterSplit, bypassCoolerStorageNameCheck))
                .Select(p => new PackingListProduct
                {
                    ItemName = p.Key.ItemName,
                    Comment = p.Key.Comment,
                    Subtitle = p.Key.Subtitle,
                    Items = AggregatePackingProductItems(p)
                })
                .ToList();
        }

        // Section sort order now lives in KLS.Common.PackingStorageOrder so the
        // single-invoice and route-wide paths share one source of truth. Previous
        // local copy returned 0/1/2 (Cooler/Prepack/rest) which fell through to
        // alphabetical for non-Cooler sections — that's the bug the consolidation fixes.

        // Shared packing-style report model builder. Standalone PackingList remains the
        // source of truth, and filtered reports such as Harvills / Store Total now reuse
        // the same storage/product/qty layout instead of their own legacy templates.
        private RptPackingList BuildPackingListReport(
            IEnumerable<RptPackingItem> packingItems,
            DateOnly? shipDate,
            string? shipRoute,
            int? salesId,
            string? payeeName,
            string? truckNumber,
            string? reportTitle = null,
            bool useLbsOuterSplit = false,
            bool useWeightLikeOuterSplit = false,
            bool bypassCoolerStorageNameCheck = false,
            bool useUnitSplitAcrossAllStorages = false)
        {
            var itemList = packingItems.ToList();

            var packingStorage = itemList
                .GroupBy(c => c.StorageName)
                .OrderBy(g => PackingStorageOrder.GetSortOrder(g.Key))
                .ThenBy(g => g.Key)
                .Select(g => new PackingListStorage
                {
                    StorageName = g.Key,
                    WeightTotal = g.Sum(c => c.ItemWeight),
                    Products = BuildPackingProducts(g, useLbsOuterSplit, useWeightLikeOuterSplit, bypassCoolerStorageNameCheck, useUnitSplitAcrossAllStorages)
                })
                .ToList();

            return new RptPackingList
            {
                ReportTitle = reportTitle,
                ShipDate = shipDate,
                ShipRoute = shipRoute,
                SalesId = salesId,
                PayeeName = payeeName,
                TruckNumber = truckNumber,
                Storages = packingStorage
            };
        }

        // Default standalone grouping is ItemName + Comment only.
        // When TotalSplit mode is enabled, Cooler lbs rows that would look identical
        // on the page (same item/comment/qty after normalizing comment text) but
        // come from different sales split into separate outer boxes.
        //
        // Use SalesNumber as the actual split key so two different orders for the
        // same customer still separate correctly. Keep PayeeName as the visual
        // subtitle so the printed box still shows a readable customer marker.
        private static PackingProductGroupKey ResolvePackingProductGroupKey(
            RptPackingItem item,
            IGrouping<string?, RptPackingItem> storageGroup,
            bool useLbsOuterSplit,
            bool useWeightLikeOuterSplit,
            bool bypassCoolerStorageNameCheck)
        {
            var isSplitCandidateUnit = useWeightLikeOuterSplit
                ? IsWeightLikeUnit(item.Unit)
                : string.Equals(item.Unit, "lbs", StringComparison.OrdinalIgnoreCase);

            if (!useLbsOuterSplit
                || (!bypassCoolerStorageNameCheck && !string.Equals(storageGroup.Key, "Cooler", StringComparison.OrdinalIgnoreCase))
                || !isSplitCandidateUnit)
            {
                return new PackingProductGroupKey(item.ItemName, item.Comment, null, null);
            }

            var normalizedComment = NormalizePackingComment(item.Comment);
            var hasVisualCollisionAcrossSales = storageGroup.Any(x =>
                (useWeightLikeOuterSplit
                    ? IsWeightLikeUnit(x.Unit)
                    : string.Equals(x.Unit, "lbs", StringComparison.OrdinalIgnoreCase))
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

        // Trim + collapse case/spacing noise so "1 cs " and "1 CS" still count as the
        // same visible comment for TotalSplit collision detection.
        private static string NormalizePackingComment(string? comment)
            => string.IsNullOrWhiteSpace(comment) ? string.Empty : comment.Trim();

        // Cooler weight rows are not consistently stored as literal "lbs".
        // Store Total can return values such as "lb" or "pk5lb", and those rows
        // should still participate in the same split-aware behavior as TotalSplit.
        private static bool IsWeightLikeUnit(string? unit)
        {
            if (string.IsNullOrWhiteSpace(unit))
                return false;

            var normalized = unit.Trim().ToLowerInvariant();
            return normalized.Contains("lb");
        }

        private sealed record PackingProductGroupKey(
            string? ItemName,
            string? Comment,
            string? SplitKey,
            string? Subtitle);

        public IEnumerable<RptBalanceSheet>? BalanceSheet(DateOnly? endDate)
        {
            var balance = Uow.Reports.BalanceSheet(endDate)
                .AsEnumerable()
                .OrderBy(r => r.CategorySort0 ?? 9999)
                .ThenBy(r => r.CategorySort1 ?? 9999)
                .ThenBy(r => r.CategorySort2 ?? 9999)
                .ThenBy(r => r.CategorySort3 ?? 9999)
                .ThenBy(r => r.AccountSortOrder ?? 9999)
                .ThenBy(r => r.AccountName)
                .ToList();

            var result = balance
                .Where(x => !string.IsNullOrEmpty(x.CategoryLevel0))
                .GroupBy(a => a.CategoryLevel0)
                .OrderBy(g => g.Min(x => x.CategorySort0))
                .Select(g0 => new RptBalanceSheet
                {
                    GroupName = g0.Key,
                    ClassCode = g0.First().ClassCode,
                    GroupTotal = g0.Sum(x => x.ClosingBalance ?? 0),

                    // Accounts directly under Level 0 (no Level1)
                    Items = g0.Where(x => string.IsNullOrEmpty(x.CategoryLevel1))
                        .Select(a => new RptBalanceSheetItem
                        {
                            AccountId = a.AccountId,
                            AccountCode = a.AccountCode,
                            AccountName = a.AccountName,
                            ClassCode = a.ClassCode,
                            ClosingBalance = a.ClosingBalance
                        }).ToList(),

                    // Sub-groups that have Level1
                    Children = g0.Where(x => !string.IsNullOrEmpty(x.CategoryLevel1))
                        .GroupBy(a => a.CategoryLevel1)
                        .OrderBy(g => g.Min(x => x.CategorySort1))
                        .Select(g1 => new RptBalanceSheet
                        {
                            GroupName = g1.Key,
                            GroupTotal = g1.Sum(x => x.ClosingBalance ?? 0),

                            Items = g1.Where(x => string.IsNullOrEmpty(x.CategoryLevel2))
                                .Select(a => new RptBalanceSheetItem
                                {
                                    AccountCode = a.AccountCode,
                                    AccountName = a.AccountName,
                                    ClassCode = a.ClassCode,
                                    ClosingBalance = a.ClosingBalance
                                }).ToList(),

                            Children = g1.Where(x => !string.IsNullOrEmpty(x.CategoryLevel2))
                                .GroupBy(a => a.CategoryLevel2)
                                .OrderBy(g => g.Min(x => x.CategorySort2))
                                .Select(g2 => new RptBalanceSheet
                                {
                                    GroupName = g2.Key,
                                    GroupTotal = g2.Sum(x => x.ClosingBalance ?? 0),

                                    Items = g2.Select(a => new RptBalanceSheetItem
                                    {
                                        AccountId = a.AccountId,
                                        AccountCode = a.AccountCode,
                                        AccountName = a.AccountName,
                                        ClassCode = a.ClassCode,
                                        ClosingBalance = a.ClosingBalance
                                    }).ToList(),

                                    Children = null
                                }).ToList()
                        }).ToList()
                })
                .ToList();

            return result;
        }

        public IEnumerable<RptProfitLoss>? ProfitLoss(ReportRequest reportReq)
        {
            var pl = Uow.Reports.ProfitLoss(reportReq).ToList();

            var result = pl
                .GroupBy(a => a.CategoryLevel0 ?? "Uncategorized")
                .Select(g0 =>
                {
                    var sales = g0.FirstOrDefault(x => x.AccountCode == "@ISALE")?.AcctBalance ?? 0m;
                    var total0 = g0.Sum(x => x.AcctBalance);
                    var grossMargin = total0 / (sales != 0m ? sales : 1m);

                    return new RptProfitLoss
                    {
                        GroupName = g0.Key,
                        ClassCode = g0.First().ClassCode,
                        GroupTotal = total0,
                        GrossMargin = grossMargin,
                        Children = BuildLevel1Children(g0)
                    };
                })
                .ToList();

            return result;
        }

        private List<RptProfitLoss> BuildLevel1Children(IGrouping<string, RptProfitLossRow> g0)
        {
            var children = new List<RptProfitLoss>();

            // Rows with null Level1 → direct leaf accounts under Level0
            var leafRows = g0.Where(a => a.CategoryLevel1 == null).ToList();
            foreach (var a in leafRows)
            {
                children.Add(new RptProfitLoss
                {
                    GroupName = a.AccountName,
                    AccountId = a.AccountId,
                    AccountCode = a.AccountCode,
                    GroupTotal = a.AcctBalance,
                    Children = null
                });
            }

            // Rows with non-null Level1 → group into sub-groups
            var grouped = g0.Where(a => a.CategoryLevel1 != null)
                .GroupBy(a => a.CategoryLevel1!);
            foreach (var g1 in grouped)
            {
                children.Add(new RptProfitLoss
                {
                    GroupName = g1.Key,
                    GroupTotal = g1.Sum(x => x.AcctBalance),
                    Children = BuildLevel2Children(g1)
                });
            }

            return children;
        }

        private List<RptProfitLoss> BuildLevel2Children(IGrouping<string, RptProfitLossRow> g1)
        {
            var children = new List<RptProfitLoss>();

            // Rows with null Level2 → direct leaf accounts under Level1
            var leafRows = g1.Where(a => a.CategoryLevel2 == null).ToList();
            foreach (var a in leafRows)
            {
                children.Add(new RptProfitLoss
                {
                    GroupName = a.AccountName,
                    AccountId = a.AccountId,
                    AccountCode = a.AccountCode,
                    GroupTotal = a.AcctBalance,
                    Children = null
                });
            }

            // Rows with non-null Level2 → group into sub-groups with leaf accounts
            var grouped = g1.Where(a => a.CategoryLevel2 != null)
                .GroupBy(a => a.CategoryLevel2!);
            foreach (var g2 in grouped)
            {
                children.Add(new RptProfitLoss
                {
                    GroupName = g2.Key,
                    GroupTotal = g2.Sum(x => x.AcctBalance),
                    Children = g2.Select(a => new RptProfitLoss
                    {
                        GroupName = a.AccountName,
                        AccountId = a.AccountId,
                        AccountCode = a.AccountCode,
                        GroupTotal = a.AcctBalance,
                        Children = null
                    }).ToList()
                });
            }

            return children;
        }

        public IEnumerable<RptSalesTax>? SalesTax(ReportRequest reportReq)
        {
            return Uow.Reports.SalesTax(reportReq);
        }

        public IQueryable<RptServiceSummary> ServiceSummary(ReportRequest reportReq)
        {
            return Uow.Reports.ServiceSummary(reportReq);
        }

        public IEnumerable<RptSalesCallListRow> SalesCallList()
        {
            return Uow.Reports.SalesCallList().ToList();
        }

        public IEnumerable<RptBasicItemRow> BasicItem()
        {
            return Uow.Reports.BasicItem().ToList();
        }

        public IEnumerable<RptItemAvgCostReviewRow> ItemAvgCostReview()
        {
            return Uow.Reports.ItemAvgCostReview().ToList();
        }

        public IEnumerable<RptVendorPurchaseSummary> VendorPurchaseSummary(bool includeClosed)
        {
            return Uow.Reports.VendorPurchaseSummary(includeClosed).ToList();
        }

        public IEnumerable<RptCustomerSalesSummary> CustomerSalesSummary(bool includeClosed, int? salesRepId)
        {
            // Sales-role users always see only their own customers, no matter
            // what the request passed. Same server-trusted override pattern
            // used by 9 other sales reports in this file (search IsSalesRole).
            if (UserContext.IsSalesRole)
            {
                salesRepId = UserContext.EmpId;
            }

            return Uow.Reports.CustomerSalesSummary(includeClosed, salesRepId).ToList();
        }

        public IEnumerable<RptSalesSummary> SalesSummary(string grain, DateOnly? startDate, DateOnly? endDate, int? salesRepId)
        {
            // Sales-role users always see only their own sales, no matter what
            // the request passed. Filters Sales.SalesRepId (transactional credit)
            // rather than Customer.SalesRepId; this matches the convention used by
            // Report_SalesDaily, Report_SalesCommission, and the rest of the
            // transactional sales reports.
            if (UserContext.IsSalesRole)
            {
                salesRepId = UserContext.EmpId;
            }

            return Uow.Reports.SalesSummary(grain, startDate, endDate, salesRepId).ToList();
        }

        public IEnumerable<RptResponsible> Responsible(DateOnly? shipDate)
        {
            var data = Uow.Reports.Responsible(shipDate).ToList();

            var result = data
                .GroupBy(c => c.ResType)
                .Select(g => new RptResponsible
                {
                    ResType = g.Key,
                    Items = g.ToList()
                });

            return result;
        }

        public List<RptDailySummary> DailySummary(DateOnly? shipDate)
        {
            var data = Uow.Reports.DailySummary(shipDate).ToList();

            var result = data
                .GroupBy(x => x.ShipRoute)
                .Select(group =>
                {
                    var first = group.First();

                    return new RptDailySummary
                    {
                        ShipRoute = group.Key,
                        TruckNumber = first.TruckNumber,
                        Driver = first.Driver,
                        Loader = first.Loader,
                        Checker = first.Checker,
                        Officer = first.Officer,
                        Invoices = group.ToList(),
                        ReturnItems = _salesRouteDetailService
                                        .GetList(first.ShipDate, group.Key)?.ToList()
                    };
                })
                .ToList();

            return result;
        }

        public IQueryable<RptPricesheet> Pricesheet(int payeeId)
        {
            return Uow.Reports.Pricesheet(payeeId);
        }

        public IQueryable<RptOrderGuideItem> OrderGuide(int payeeId)
        {
            return Uow.Reports.OrderGuide(payeeId);
        }

        public IQueryable<RptCustItemVolume> CustItemVolume(int payeeId)
        {
            return Uow.Reports.CustItemVolume(payeeId);
        }

        public IEnumerable<RptCustSalesByItem>? CustSalesByItem(ReportRequest reportReq)
        {
            return Uow.Reports.CustSalesByItem(reportReq);
        }

        public IQueryable<RptSalesHistoryRow> SalesHistory(ReportRequest reportReq)
        {
            return Uow.Reports.SalesHistory(reportReq);
        }

        public IQueryable<RptPurchaseHistoryRow> PurchaseHistory(ReportRequest reportReq)
        {
            return Uow.Reports.PurchaseHistory(reportReq);
        }

        public IQueryable<RptItemCustomerAnalysisRow> ItemCustomerAnalysis(ItemCustomerAnalysisRequest reportReq)
        {
            return Uow.Reports.ItemCustomerAnalysis(reportReq);
        }

        public IQueryable<RptItemVendorAnalysisRow> ItemVendorAnalysis(ItemCustomerAnalysisRequest reportReq)
        {
            return Uow.Reports.ItemVendorAnalysis(reportReq);
        }

        public IQueryable<RptItemAnalysis> ItemAnalysis(ItemAnalysisRequest reportReq)
        {
            return Uow.Reports.ItemAnalysis(reportReq);
        }

        public IQueryable<RptCustPayment> CustPayment(ReportRequest reportReq)
        {
            return Uow.Reports.CustPayment(reportReq);
        }

        public IQueryable<RptCreditMemo> CreditMemo(ReportRequest reportReq)
        {
            if (UserContext.IsSalesRole)
            {
                reportReq.SalesRepId = UserContext.EmpId;
            }

            return Uow.Reports.CreditMemo(reportReq);
        }

        public IQueryable<RptJobSummary> JobSummary(ReportRequest reportReq)
        {
            return Uow.Reports.JobSummary(reportReq);
        }

        public IQueryable<RptPayroll> Payroll(ReportRequest reportReq)
        {
            return Uow.Reports.Payroll(reportReq);
        }

        public IQueryable<RptEmpLoanLedger> EmpLoanLedger(ReportRequest reportReq)
        {
            return Uow.Reports.EmpLoanLedger(reportReq);
        }

        public IQueryable<RptLedgerByPayeeRow> LedgerByPayee(ReportRequest reportReq)
        {
            return Uow.Reports.LedgerByPayee(reportReq);
        }

        public RptBankRecon BankRecon(int bankReconId)
        {
            var data = Uow.Reports.BankRecon(bankReconId).AsEnumerable().ToList();

            var first = data.FirstOrDefault();

            return new RptBankRecon
            {
                AccountName = first?.AccountName,
                StatementDate = first?.StatementDate,
                StatementBalance = first?.StatementBalance,
                BeginningBalance = first?.BeginningBalance,
                ClearedDeposits = data.Where(r => r.IsCleared && r.Amount > 0).ToList(),
                ClearedPayments = data.Where(r => r.IsCleared && r.Amount < 0).ToList(),
                OutstandingDeposits = data.Where(r => !r.IsCleared && r.Amount > 0).ToList(),
                OutstandingPayments = data.Where(r => !r.IsCleared && r.Amount < 0).ToList(),
                TotalClearedDeposits = data.Where(r => r.IsCleared && r.Amount > 0).Sum(r => r.Amount ?? 0),
                TotalClearedPayments = data.Where(r => r.IsCleared && r.Amount < 0).Sum(r => r.Amount ?? 0),
                TotalOutstandingDeposits = data.Where(r => !r.IsCleared && r.Amount > 0).Sum(r => r.Amount ?? 0),
                TotalOutstandingPayments = data.Where(r => !r.IsCleared && r.Amount < 0).Sum(r => r.Amount ?? 0)
            };
        }

        public IQueryable<RptAPCheckRow> APCheck(ReportRequest reportReq)
        {
            return Uow.Reports.APCheck(reportReq);
        }

        public IQueryable<RptCheckToBePrintedRow> CheckToBePrinted(string? pmtMethod)
        {
            return Uow.Reports.CheckToBePrinted(pmtMethod);
        }

        public RptARInvoice APInvoice(ReportRequest reportReq)
        {
            var data = Uow.Reports.APInvoice(reportReq).AsEnumerable().ToList();

            var terms = data
                .GroupBy(r => r.TermId)
                .Select(g =>
                {
                    var dueDays = g.First().DueDays ?? 0;
                    var term = Uow.Terms.Find(t => t.TermId == g.Key).FirstOrDefault();
                    return new RptARInvoiceTerm
                    {
                        TermName = term?.TermName ?? "No Term",
                        DueDays = dueDays,
                        Payee = g.Select(r => new RptARInvoiceRow
                        {
                            PayeeId = r.PayeeId,
                            PayeeName = r.PayeeName,
                            PhoneDesc1 = r.PhoneDesc1,
                            Phone1 = r.Phone1,
                            Inv30 = r.Inv30,
                            Invoice60 = r.Invoice60,
                            Invoice90 = r.Invoice90,
                            InvoiceOver90 = r.InvoiceOver90,
                            PayeeTotalDue = r.PayeeTotalDue
                        }).ToList()
                    };
                })
                .ToList();

            return new RptARInvoice
            {
                Terms = terms,
                Sec1 = "0-30",
                Sec2 = "31-60",
                Sec3 = "61-90",
                Sec4 = "Over 90",
                Inv30Total = data.Sum(r => r.Inv30 ?? 0),
                Inv60Total = data.Sum(r => r.Invoice60 ?? 0),
                Inv90Total = data.Sum(r => r.Invoice90 ?? 0),
                InvOver90Total = data.Sum(r => r.InvoiceOver90 ?? 0),
                ARTotal = data.Sum(r => r.PayeeTotalDue ?? 0)
            };
        }

        // Per-invoice AP Aging — passthrough. SP already filters to Stage=6 Billed
        // + AmountDue<>0 and returns mirror bucket columns; frontend groups by
        // vendor + computes subtotals/totals client-side.
        public IQueryable<RptAPAgingRow> APAging(RptAPAgingReq req)
        {
            return Uow.Reports.APAging(req);
        }

        // Per-invoice AR Aging — passthrough. SP filters by ShipId
        // (portal/admin AR identity model) + AmountDue<>0 (no stage filter,
        // matches View_Customer aggregation) and returns mirror bucket columns
        // + denormalized LastPaymentDate/Amount per row. Frontend groups by
        // customer + computes subtotals/totals/PastDueOnly client-side.
        public IQueryable<RptARAgingRow> ARAging(RptARAgingReq req)
        {
            return Uow.Reports.ARAging(req);
        }

        public IQueryable<RptSalesDetailRow> SalesDetail(ReportRequest reportReq)
        {
            if (UserContext.IsSalesRole)
            {
                reportReq.SalesRepId = UserContext.EmpId;
            }

            return Uow.Reports.SalesDetail(reportReq);
        }

        public IQueryable<RptSalesDaily2Row> SalesDaily2(ReportRequest reportReq)
        {
            if (UserContext.IsSalesRole)
            {
                reportReq.SalesRepId = UserContext.EmpId;
            }

            return Uow.Reports.SalesDaily2(reportReq);
        }

        public IQueryable<RptSalesByInvoiceRow> SalesByInvoice(ReportRequest reportReq)
        {
            if (UserContext.IsSalesRole)
            {
                reportReq.SalesRepId = UserContext.EmpId;
            }

            return Uow.Reports.SalesByInvoice(reportReq);
        }

        public RptSalesYearly SalesYearly()
        {
            var data = Uow.Reports.SalesYearly().AsEnumerable().ToList();

            var yearlySales = data
                .GroupBy(r => new { r.SalesMonth, r.SalesMonthName })
                .OrderBy(g => g.Key.SalesMonth)
                .Select(g =>
                {
                    var y1Total = g.Sum(r => r.Y1 ?? 0);
                    var y2Total = g.Sum(r => r.Y2 ?? 0);
                    var y3Total = g.Sum(r => r.Y3 ?? 0);
                    return new RptSalesYearlyMonth
                    {
                        Month = g.Key.SalesMonthName,
                        Y1Total = y1Total,
                        Y2Total = y2Total,
                        Y3Total = y3Total,
                        // Match legacy behavior: month percent comes from the proc row values.
                        Y1Perc = g.FirstOrDefault()?.Y1Percent ?? 0,
                        Y2Perc = g.FirstOrDefault()?.Y2Percent ?? 0,
                        MonthlySales = g.ToList()
                    };
                })
                .ToList();

            var accounts = data
                .GroupBy(r => new { r.AccountId, r.AccountName })
                .Select(g => new RptSalesYearlyAccount
                {
                    AcctName = g.Key.AccountName,
                    Y1Total = g.Sum(r => r.Y1 ?? 0),
                    Y2Total = g.Sum(r => r.Y2 ?? 0),
                    Y3Total = g.Sum(r => r.Y3 ?? 0)
                })
                .ToList();

            var grandY1 = data.Sum(r => r.Y1 ?? 0);
            var grandY2 = data.Sum(r => r.Y2 ?? 0);
            var grandY3 = data.Sum(r => r.Y3 ?? 0);

            return new RptSalesYearly
            {
                YearlySales = yearlySales,
                Accounts = accounts,
                Y1Total = grandY1,
                Y2Total = grandY2,
                Y3Total = grandY3,
                Y1Perc = grandY2 != 0 ? (grandY1 - grandY2) / grandY2 : 0,
                Y2Perc = grandY3 != 0 ? (grandY2 - grandY3) / grandY3 : 0
            };
        }

        public IQueryable<RptSalesCommissionRow> SalesCommission(ReportRequest reportReq)
        {
            if (UserContext.IsSalesRole)
            {
                reportReq.SalesRepId = UserContext.EmpId;
            }

            return Uow.Reports.SalesCommission(reportReq);
        }

        public IQueryable<RptSalesCommission2Row> SalesCommission2(ReportRequest reportReq)
        {
            if (UserContext.IsSalesRole)
            {
                reportReq.SalesRepId = UserContext.EmpId;
            }

            return Uow.Reports.SalesCommission2(reportReq);
        }

        public IQueryable<RptSalesCommission3Row> SalesCommission3(ReportRequest reportReq)
        {
            // self-scoping matches v2: a Sales-role user only sees their own rows
            if (UserContext.IsSalesRole)
            {
                reportReq.SalesRepId = UserContext.EmpId;
            }

            return Uow.Reports.SalesCommission3(reportReq);
        }

        public RptARInvoice ARInvoice(ReportRequest reportReq)
        {
            if (UserContext.IsSalesRole)
            {
                reportReq.SalesRepId = UserContext.EmpId;
            }

            var data = Uow.Reports.ARInvoice(reportReq).AsEnumerable().ToList();

            var terms = data
                .GroupBy(r => r.TermId)
                .Select(g =>
                {
                    var dueDays = g.First().DueDays ?? 0;
                    var term = Uow.Terms.Find(t => t.TermId == g.Key).FirstOrDefault();
                    var termName = term?.TermName ?? "No Term";
                    return new RptARInvoiceTerm
                    {
                        TermName = termName,
                        DueDays = dueDays,
                        Payee = g.ToList()
                    };
                })
                .ToList();

            return new RptARInvoice
            {
                Terms = terms,
                Sec1 = "0-30",
                Sec2 = "31-60",
                Sec3 = "61-90",
                Sec4 = "Over 90",
                Inv30Total = data.Sum(r => r.Inv30 ?? 0),
                Inv60Total = data.Sum(r => r.Invoice60 ?? 0),
                Inv90Total = data.Sum(r => r.Invoice90 ?? 0),
                InvOver90Total = data.Sum(r => r.InvoiceOver90 ?? 0),
                ARTotal = data.Sum(r => r.PayeeTotalDue ?? 0)
            };
        }

        public RptARMonth ARMonth(ReportRequest reportReq)
        {
            if (UserContext.IsSalesRole)
            {
                reportReq.SalesRepId = UserContext.EmpId;
            }

            var data = Uow.Reports.ARMonth(reportReq).AsEnumerable().ToList();

            var regions = data
                .GroupBy(r => r.Region ?? "No Region")
                .Select(g => new RptARMonthRegion
                {
                    Region = g.Key,
                    Total = g.Sum(r => r.Total ?? 0),
                    Customers = g.ToList()
                })
                .ToList();

            return new RptARMonth
            {
                Regions = regions,
                Total = data.Sum(r => r.Total ?? 0)
            };
        }

        public IEnumerable<RptARRollforward> ARRollforward(ReportRequest reportReq)
        {
            return Uow.Reports.ARRollforward(reportReq).AsEnumerable().ToList();
        }

        public IEnumerable<RptSalesDaily>? SalesDaily(ReportRequest reportReq)
        {
            if (UserContext.IsSalesRole)
            {
                reportReq.SalesRepId = UserContext.EmpId;
            }

            return Uow.Reports.SalesDaily(reportReq);
        }

        public IEnumerable<RptDescDollar>? DescDollar(ReportRequest reportReq)
        {
            return Uow.Reports.DescDollar(reportReq);
        }

        public IEnumerable<RptDescDollar>? VendorDescDollar(ReportRequest reportReq)
        {
            return Uow.Reports.VendorDescDollar(reportReq);
        }

        public IEnumerable<RptPaymentHistory>? PaymentHistory(int payeeId)
        {
            return Uow.CustomerPayments.Find(s => s.PayeeId == payeeId).OrderByDescending(c => c.PaymentDate).ToList()
                .GroupBy(s => new { s.PaymentDate.Value.Year, s.PaymentDate.Value.Month })
                .Select(g => new RptPaymentHistory
                {
                    PaymentMonth = new DateTimeFormatInfo().GetMonthName(g.Key.Month) + " - " + g.Key.Year.ToString(),
                    Payments = g.ToList()
                }).ToList();
        }

        public IEnumerable<RptAccountHistory>? AccountHistory(int payeeId)
        {
            return Uow.Reports.AccountHistory(payeeId);
        }

        public RptLedger? Ledger(ReportRequest reportReq)
        {
            var rows = Uow.Reports.Ledger(reportReq).ToList();
            if (!rows.Any()) return new RptLedger { OpeningBalance = 0, Rows = new() };

            return new RptLedger
            {
                OpeningBalance = rows.First().OpeningBalance,
                Rows = rows
            };
        }

        #region --- Inventory Reports ---

        public IEnumerable<RptInventoryStatusRow> InventoryStatus(InventoryReportRequest req)
        {
            return Uow.Reports.InventoryStatus(req).AsEnumerable();
        }

        public RptPOInventoryStatus POInventoryStatus()
        {
            var companyCode = _companyService.GetDefault()?.CompanyCode?.Trim();
            if (!string.Equals(companyCode, "GUS", StringComparison.OrdinalIgnoreCase))
                throw new UnauthorizedAccessException("PO Inventory Status is only available for GUS.");

            var status = Uow.Reports.InventoryStatus(new InventoryReportRequest())
                .AsEnumerable()
                .Where(IsInGusPOInventoryStatusScope)
                .ToList();

            var itemIds = status
                .Select(r => r.ItemId)
                .ToHashSet();

            var incoming = Uow.Reports.InventoryIncoming()
                .AsEnumerable()
                .Where(r => itemIds.Contains(r.ItemId))
                .ToList();

            return new RptPOInventoryStatus
            {
                Status = status,
                Incoming = incoming
            };
        }

        public IEnumerable<RptReorderRow> Reorder(InventoryReportRequest req)
        {
            return Uow.Reports.Reorder(req).AsEnumerable();
        }

        public IEnumerable<RptInventoryValuationRow> InventoryValuation(InventoryReportRequest req)
        {
            return Uow.Reports.InventoryValuation(req).AsEnumerable();
        }

        public IEnumerable<RptInventoryMovementRow> InventoryMovement(InventoryReportRequest req)
        {
            return Uow.Reports.InventoryMovement(req).AsEnumerable();
        }

        public IEnumerable<RptInventoryIncomingRow> InventoryIncoming()
        {
            return Uow.Reports.InventoryIncoming().AsEnumerable();
        }

        public IEnumerable<RptWorksheetGroup> WorksheetPattern(WorksheetPatternReportRequest req)
        {
            var rows = Uow.Reports.WorksheetPattern(req).ToList();

            var groups = string.Equals(req.Filterby, "vendor", StringComparison.OrdinalIgnoreCase)
                ? rows.GroupBy(r => string.IsNullOrWhiteSpace(r.PayeeName) ? "No Vendor" : r.PayeeName)
                : rows.GroupBy(r => string.IsNullOrWhiteSpace(r.Storage) ? "No Storage" : r.Storage);

            return groups
                .Select(g => new RptWorksheetGroup
                {
                    Group = g.Key,
                    Items = g.ToList()
                })
                .OrderBy(g => g.Group)
                .ToList();
        }

        private static bool IsInGusPOInventoryStatusScope(RptInventoryStatusRow row)
        {
            var cat0 = row.Cat0?.Trim();
            var cat1 = row.Cat1?.Trim();

            return !string.IsNullOrWhiteSpace(cat0)
                && GusPOInventoryStatusCat0.Contains(cat0)
                && !GusPOInventoryStatusExcludedCat1.Contains(cat1 ?? string.Empty);
        }

        #endregion

        public RptCheckPrint? CheckPrint(int vendorPaymentId)
        {
            return Uow.Reports.CheckPrint(vendorPaymentId);
        }

        public IQueryable<RptCheckPrintDetail> CheckPrintDetail(int vendorPaymentId)
        {
            return Uow.Reports.CheckPrintDetail(vendorPaymentId);
        }

        public IEnumerable<RptMarketOrder> MarketOrder(ReportRequest reportReq)
        {
            return Uow.Reports.MarketOrder(reportReq);
        }
    }
}
