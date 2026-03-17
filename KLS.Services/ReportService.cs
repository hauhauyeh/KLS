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
                //Promotions = _PromotionManager.GetDisplay(),
            };
        }

        public RptCustStmt CustStmt(int payeeId)
        {
            return Uow.Reports.CustStmt(payeeId);

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

            var packingStorage = packingItems.GroupBy(c => c.StorageName).Select(g => new PackingListStorage
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

            var payeeName = "";

            if (req.SalesId.HasValue)
            {
                var sales = Uow.Sales.GetById(req.SalesId.Value);
                payeeName = Uow.Payees.GetById(sales.ShipId.Value)?.PayeeName;
                req.ShipDate = sales.ShipDate;
                req.ShipRoute = sales.ShipRoute;
            }

            return new RptPackingList
            {
                ShipDate = req.ShipDate,
                ShipRoute = req.ShipRoute,
                SalesId = req.SalesId,
                PayeeName = payeeName,
                TruckNumber = _salesRouteService.GetByDateRoute(req.ShipDate, req.ShipRoute)?.TruckNumber,
                Storages = packingStorage
            };
        }

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

        public IEnumerable<RptSalesDaily>? SalesDaily(ReportRequest reportReq)
        {
            return Uow.Reports.SalesDaily(reportReq);
        }

        public IEnumerable<RptDescDollar>? DescDollar(ReportRequest reportReq)
        {
            return Uow.Reports.DescDollar(reportReq);
        }

        public IEnumerable<RptPaymentHistory>? PaymentHistory(int payeeId)
        {
            return Uow.CustomerPayments.Find(s => s.CustomerPaymentId == payeeId).OrderByDescending(c => c.PaymentDate).ToList()
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
    }
}
