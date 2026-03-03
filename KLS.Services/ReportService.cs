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
            var balance = Uow.Reports.BalanceSheet(endDate).ToList();

            var result = balance
                .GroupBy(a => a.CategoryLevel0)
                .Select(g0 => new RptBalanceSheet
                {
                    GroupName = g0.Key,
                    GroupTotal = g0.Sum(x => x.ClosingBalance),
                    Children = g0
                        .GroupBy(a => a.CategoryLevel1)
                        .Select(g1 => new RptBalanceSheet
                        {
                            GroupName = g1.Key,
                            Children = g1
                                .GroupBy(a => a.CategoryLevel2)
                                .Select(g2 => new RptBalanceSheet
                                {
                                    GroupName = g2.Key,
                                    GroupTotal = g2.Sum(x => x.ClosingBalance),
                                    // Leaf nodes = accounts (still using same RptBalanceSheet type)
                                    Children = g2.Select(a => new RptBalanceSheet
                                    {
                                        GroupName = a.AccountName,
                                        AccountCode = a.AccountCode,
                                        GroupTotal = a.ClosingBalance,
                                        Children = null
                                    }).ToList()
                                }).ToList(),
                            GroupTotal = g1.Sum(x => x.ClosingBalance)
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
                        GroupTotal = total0,
                        GrossMargin = grossMargin,

                        Children = g0
                            .GroupBy(a => a.CategoryLevel1 ?? "Uncategorized")
                            .Select(g1 => new RptProfitLoss
                            {
                                GroupName = g1.Key,
                                GroupTotal = g1.Sum(x => x.AcctBalance),

                                Children = g1
                                    .GroupBy(a => a.CategoryLevel2 ?? "Uncategorized")
                                    .Select(g2 => new RptProfitLoss
                                    {
                                        GroupName = g2.Key,

                                        // Level3 (accounts) mapped into same class as leaf nodes
                                        Children = g2.Select(a => new RptProfitLoss
                                        {
                                            GroupName = a.AccountName,
                                            AccountCode = a.AccountCode,
                                            GroupTotal = a.AcctBalance,
                                            Children = null
                                        }).ToList(),

                                        GroupTotal = g2.Sum(x => x.AcctBalance)
                                    })
                                    .ToList()
                            })
                            .ToList()
                    };
                })
                .ToList();

            return result;
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
    }
}
