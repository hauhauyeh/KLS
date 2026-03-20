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

        public IQueryable<RptCustPayment> CustPayment(ReportRequest reportReq)
        {
            return Uow.Reports.CustPayment(reportReq);
        }

        public IQueryable<RptCreditMemo> CreditMemo(ReportRequest reportReq)
        {
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
                ClearedDeposits = data.Where(r => r.IsCleared == 1 && r.Amount > 0).ToList(),
                ClearedPayments = data.Where(r => r.IsCleared == 1 && r.Amount < 0).ToList(),
                OutstandingDeposits = data.Where(r => r.IsCleared == 0 && r.Amount > 0).ToList(),
                OutstandingPayments = data.Where(r => r.IsCleared == 0 && r.Amount < 0).ToList(),
                TotalClearedDeposits = data.Where(r => r.IsCleared == 1 && r.Amount > 0).Sum(r => r.Amount ?? 0),
                TotalClearedPayments = data.Where(r => r.IsCleared == 1 && r.Amount < 0).Sum(r => r.Amount ?? 0),
                TotalOutstandingDeposits = data.Where(r => r.IsCleared == 0 && r.Amount > 0).Sum(r => r.Amount ?? 0),
                TotalOutstandingPayments = data.Where(r => r.IsCleared == 0 && r.Amount < 0).Sum(r => r.Amount ?? 0)
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
                        IsFirstColumn = dueDays > 0 && dueDays < 30,
                        Payee = g.Select(r => new RptARInvoiceRow
                        {
                            PayeeId = r.PayeeId,
                            PayeeName = r.PayeeName,
                            PhoneDesc1 = r.PhoneDesc1,
                            Phone1 = r.Phone1,
                            Inv0 = r.Inv0,
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

        public IQueryable<RptSalesDetailRow> SalesDetail(ReportRequest reportReq)
        {
            return Uow.Reports.SalesDetail(reportReq);
        }

        public IQueryable<RptSalesDaily2Row> SalesDaily2(ReportRequest reportReq)
        {
            return Uow.Reports.SalesDaily2(reportReq);
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
                        Y1Perc = y2Total != 0 ? (y1Total - y2Total) / y2Total : 0,
                        Y2Perc = y3Total != 0 ? (y2Total - y3Total) / y3Total : 0,
                        MonthlySales = g.ToList()
                    };
                })
                .ToList();

            var accounts = data
                .GroupBy(r => r.AccountName)
                .Select(g => new RptSalesYearlyAccount
                {
                    AcctName = g.Key,
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
            return Uow.Reports.SalesCommission(reportReq);
        }

        public IQueryable<RptSalesCommission2Row> SalesCommission2(ReportRequest reportReq)
        {
            return Uow.Reports.SalesCommission2(reportReq);
        }

        public RptARInvoice ARInvoice(ReportRequest reportReq)
        {
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
                        IsFirstColumn = dueDays > 0 && dueDays < 30,
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

        #endregion
    }
}
