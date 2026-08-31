using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using KLS.Models.Reports;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class ReportRepository : KLSRepository<RptPOView>, IReportRepository
    {
        public ReportRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public Invoice Invoice(int salesId)
        {
            var SalesIdParam = new SqlParameter("@SalesId", salesId);

            return DbContext.Invoice.FromSqlRaw("[dbo].[Report_Invoice] @SalesId", SalesIdParam).ToList().FirstOrDefault();
        }

        public IQueryable<InvoiceDetail>? InvoiceDetail(int salesId)
        {
            var SalesIdParam = new SqlParameter("@SalesId", salesId);

            return DbContext.InvoiceDetail.FromSqlRaw("[dbo].[Report_InvoiceDetail] @SalesId", SalesIdParam).AsNoTracking();
        }

        public RptVendStmt VendStmt(int payeeId)
        {
            // Refresh AP-side cache for this vendor before reading Payee.
            // Mirrors CustStmt pattern. Rule 5 contract guarantees cached
            // Payee.* fields equal what View_Vendor would compute.
            var payeeIdParam = new SqlParameter("@PayeeId", payeeId);
            var isSalesParam = new SqlParameter("@IsSales", false);
            DbContext.Database.ExecuteSqlRaw("EXEC [dbo].[Payee_UpdateAging] @PayeeId, @IsSales", payeeIdParam, isSalesParam);

            var details = DbContext.Purchases.Where(p => p.PayeeId == payeeId && p.AmountDue != 0)
                .GroupBy(p => new { p.ArrivalDate.Value.Year, p.ArrivalDate.Value.Month })
                .Select(g => new RptVendStmtDetail
                {
                    ArrivalMonth = new DateTimeFormatInfo().GetMonthName(g.Key.Month) + " - " + g.Key.Year.ToString(),
                    Purchases = g.OrderBy(p => p.ArrivalDate).ToList()
                }).ToList();

            return new RptVendStmt
            {
                Details = details,
                Payee = DbContext.Payees.Find(payeeId)
            };
        }

        public RptCustStmt CustStmt(int payeeId, StatementScope scope = StatementScope.ShipTo)
        {
            var selectedCustomer = DbContext.Customers.Find(payeeId);
            var selectedCustomerBillId = selectedCustomer?.BillId;
            var isBillToChild = selectedCustomerBillId.HasValue && selectedCustomerBillId.Value != payeeId;
            var isBillToParent = DbContext.Customers.Any(c => c.BillId == payeeId && c.PayeeId != payeeId);
            var canUseBillToStatement = isBillToChild || isBillToParent;
            var effectivePayeeId = scope == StatementScope.BillTo
                ? (isBillToChild ? selectedCustomerBillId!.Value : payeeId)
                : payeeId;

            // Recalculate aging on demand before reading Payee
            var payeeIdParam = new SqlParameter("@PayeeId", effectivePayeeId);
            var isSalesParam = new SqlParameter("@IsSales", true);
            DbContext.Database.ExecuteSqlRaw("EXEC [dbo].[Payee_UpdateAging] @PayeeId, @IsSales", payeeIdParam, isSalesParam);

            var sales = scope == StatementScope.BillTo
                ? DbContext.Sales.Where(s => s.BillId == effectivePayeeId && s.AmountDue != 0)
                : DbContext.Sales.Where(s => s.ShipId == payeeId && s.AmountDue != 0);

            var salesList = sales.ToList();

            var details = salesList
                .GroupBy(s => new { s.ShipDate.Value.Year, s.ShipDate.Value.Month })
                .Select(g => new RptCustStmtDetail
                {
                    ShipMonth = new DateTimeFormatInfo().GetMonthName(g.Key.Month) + " - " + g.Key.Year.ToString(),
                    Sales = g.OrderBy(s => s.ShipDate).ToList()
                }).ToList();

            var customer = DbContext.Customers.Find(effectivePayeeId) ?? selectedCustomer;
            var payee = DbContext.Payees.Find(effectivePayeeId);
            var availableCredit = DbContext.CustomerPayments
                .Where(c => c.PayeeId == effectivePayeeId && c.UnappliedAmount != 0 && c.IsReturned == false)
                .ToList();

            var statementCurrent = scope == StatementScope.BillTo ? SumByDueAge(salesList, age => age <= 0) : payee?.PayeeCurrent;
            var statement30 = scope == StatementScope.BillTo ? SumByDueAge(salesList, age => age >= 1 && age <= 30) : payee?.Payee30;
            var statement60 = scope == StatementScope.BillTo ? SumByDueAge(salesList, age => age >= 31 && age <= 60) : payee?.Payee60;
            var statement90 = scope == StatementScope.BillTo ? SumByDueAge(salesList, age => age >= 61 && age <= 90) : payee?.Payee90;
            var statementOver90 = scope == StatementScope.BillTo ? SumByDueAge(salesList, age => age > 90) : payee?.PayeeOver90;
            var statementTotalDue = scope == StatementScope.BillTo
                ? salesList.Sum(s => s.AmountDue ?? 0)
                : payee?.PayeeTotalDue ?? 0;
            var availableCreditTotal = availableCredit.Sum(c => c.UnappliedAmount ?? 0);

            return new RptCustStmt
            {
                StatementScope = scope.ToString(),
                SelectedPayeeId = payeeId,
                EffectiveBillToId = effectivePayeeId,
                EffectiveBillToName = payee?.PayeeName,
                CanUseBillToStatement = canUseBillToStatement,
                StatementCurrent = statementCurrent,
                Statement30 = statement30,
                Statement60 = statement60,
                Statement90 = statement90,
                StatementOver90 = statementOver90,
                StatementTotalDue = statementTotalDue,
                AccountBalance = statementTotalDue - availableCreditTotal,
                Details = details,
                BillToGroups = scope == StatementScope.BillTo ? BuildBillToGroups(salesList) : null,
                Payee = payee,
                IsPromotionEnabled = customer?.IsPromotionEnabled ?? false,
                AvailableCredit = availableCredit
            };
        }

        private static decimal SumByDueAge(IEnumerable<Sales> sales, Func<int, bool> predicate)
        {
            return sales
                .Where(s => predicate(DueAge(s)))
                .Sum(s => s.AmountDue ?? 0);
        }

        private static int DueAge(Sales sales)
        {
            if (!sales.DueDate.HasValue)
                return 0;

            var age = DateOnly.FromDateTime(DateTime.Now).DayNumber - sales.DueDate.Value.DayNumber;
            return age < 0 ? 0 : age;
        }

        private List<RptCustStmtBillToGroup> BuildBillToGroups(List<Sales> sales)
        {
            var shipIds = sales
                .Where(s => s.ShipId.HasValue)
                .Select(s => s.ShipId!.Value)
                .Distinct()
                .ToList();

            var shipToNames = DbContext.Payees
                .Where(p => shipIds.Contains(p.PayeeId))
                .Select(p => new { p.PayeeId, p.PayeeName })
                .ToDictionary(p => p.PayeeId, p => p.PayeeName);

            return sales
                .GroupBy(s => s.ShipId)
                .Select(g => new RptCustStmtBillToGroup
                {
                    ShipId = g.Key,
                    ShipToName = g.Key.HasValue && shipToNames.TryGetValue(g.Key.Value, out var name) ? name : null,
                    Sales = g.OrderBy(s => s.ShipDate).ThenBy(s => s.SalesNumber).ToList()
                })
                .OrderBy(g => g.ShipToName)
                .ThenBy(g => g.ShipId)
                .ToList();
        }

        public RptPO ReportPO(int purchaseId)
        {
            var PurchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);

            return DbContext.RptPO.FromSqlRaw("[dbo].[Report_PO] @PurchaseId", PurchaseIdParam).AsEnumerable().SingleOrDefault()!;
        }

        public IQueryable<RptPODetail> ReportPODetail(int purchaseId)
        {
            var PurchaseIdParam = new SqlParameter("@purchaseId", purchaseId);

            return DbContext.RptPODetail.FromSqlRaw("[dbo].[Report_PODetail] @purchaseId", PurchaseIdParam);
        }

        #region --- Packing ---

        public IQueryable<RptPackingItem> PackingList(DocumentReq req)
        {
            var ShipDateParam = req.ShipDate.HasValue && !req.SalesId.HasValue ? new SqlParameter("@ShipDate", req.ShipDate) : new SqlParameter("@ShipDate", DBNull.Value);

            var ShipRouteParam = string.IsNullOrEmpty(req.ShipRoute) ? new SqlParameter("@ShipRoute", DBNull.Value) : new SqlParameter("@ShipRoute", req.ShipRoute);

            var SalesIdParam = req.SalesId.HasValue ? new SqlParameter("@SalesId", req.SalesId) : new SqlParameter("@SalesId", DBNull.Value);

            return DbContext.RptPackingItem.FromSqlRaw("[dbo].[Report_PackingList] @ShipDate,@ShipRoute,@SalesId", ShipDateParam, ShipRouteParam, SalesIdParam);
        }

        public IQueryable<RptHarvillsItem> Harvills(DateOnly shipDate)
        {
            var ShipDateParam = new SqlParameter("@ShipDate", shipDate);

            return DbContext.RptHarvillsItem.FromSqlRaw("[dbo].[Report_Harvills] @ShipDate", ShipDateParam);
        }

        public IQueryable<RptStoreTotalItem> StoreTotal(DateOnly shipDate)
        {
            var ShipDateParam = new SqlParameter("@ShipDate", shipDate);

            return DbContext.RptStoreTotalItem.FromSqlRaw("[dbo].[Report_StoreTotal] @ShipDate", ShipDateParam);
        }

        public IQueryable<RptSensitiveItem> Sensitive(DateOnly shipDate)
        {
            var ShipDateParam = new SqlParameter("@ShipDate", shipDate);

            return DbContext.RptSensitiveItem.FromSqlRaw("[dbo].[Report_Sensitive] @ShipDate", ShipDateParam);
        }

        public IQueryable<RptAssignTruck> AssignTruck(DateOnly shipDate)
        {
            var ShipDateParam = new SqlParameter("@ShipDate", shipDate);

            return DbContext.RptAssignTruck.FromSqlRaw("[dbo].[Report_AssignTruck] @ShipDate", ShipDateParam);
        }

        public IQueryable<RptLoadingItem> LoadingList(DocumentReq req)
        {
            var ShipDateParam = req.ShipDate.HasValue ? new SqlParameter("@ShipDate", req.ShipDate) : new SqlParameter("@ShipDate", DBNull.Value);

            var ShipRouteParam = string.IsNullOrEmpty(req.ShipRoute) ? new SqlParameter("@ShipRoute", DBNull.Value) : new SqlParameter("@ShipRoute", req.ShipRoute);

            var IsLoadParam = new SqlParameter("@IsLoad", true);

            return DbContext.RptLoadingItem.FromSqlRaw("[dbo].[Report_LoadingList] @ShipDate,@ShipRoute,@IsLoad", ShipDateParam, ShipRouteParam, IsLoadParam);
        }

        public IQueryable<RptPackingLabel> PackingLabel(DocumentReq req)
        {
            var ShipDateParam = req.ShipDate.HasValue ? new SqlParameter("@ShipDate", req.ShipDate) : new SqlParameter("@ShipDate", DBNull.Value);

            var ShipRouteParam = string.IsNullOrEmpty(req.ShipRoute) ? new SqlParameter("@ShipRoute", DBNull.Value) : new SqlParameter("@ShipRoute", req.ShipRoute);

            return DbContext.RptPackingLabel.FromSqlRaw("[dbo].[Report_PackingLabel] @ShipDate,@ShipRoute", ShipDateParam, ShipRouteParam);
        }

        #endregion

        public IQueryable<RptBalanceSheetRow> BalanceSheet(DateOnly? endDate)
        {
            var EndDateParam = endDate.HasValue ? new SqlParameter("@EndDate", endDate) : new SqlParameter("@EndDate", DBNull.Value);

            return DbContext.RptBalanceSheetRow.FromSqlRaw("[dbo].[Report_BalanceSheet] @EndDate", EndDateParam);
        }

        public IQueryable<RptProfitLossRow> ProfitLoss(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);

            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            return DbContext.RptProfitLossRow.FromSqlRaw("[dbo].[Report_ProfitLoss] @StartDate,@EndDate", StartDateParam, EndDateParam);
        }

        public IQueryable<RptSalesTax>? SalesTax(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);

            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            return DbContext.RptSalesTax.FromSqlRaw("[dbo].[Report_SalesTax] @StartDate,@EndDate", StartDateParam, EndDateParam);
        }

        public IQueryable<RptServiceSummary> ServiceSummary(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            return DbContext.RptServiceSummary.FromSqlRaw("[dbo].[Report_ServiceSummary] @StartDate,@EndDate", StartDateParam, EndDateParam);
        }

        public IQueryable<RptSalesCallListRow> SalesCallList()
        {
            return DbContext.RptSalesCallListRow.FromSqlRaw("[dbo].[Report_SalesCallList]");
        }

        public IQueryable<RptBasicItemRow> BasicItem()
        {
            return DbContext.RptBasicItemRow.FromSqlRaw("[dbo].[Report_BasicItem]");
        }

        public IQueryable<RptItemAvgCostReviewRow> ItemAvgCostReview()
        {
            return DbContext.RptItemAvgCostReviewRow.FromSqlRaw("[dbo].[Report_ItemAvgCostReview]");
        }

        public IQueryable<RptVendorPurchaseSummary> VendorPurchaseSummary(bool includeClosed)
        {
            var IncludeClosedParam = new SqlParameter("@IncludeClosed", includeClosed);

            return DbContext.RptVendorPurchaseSummary.FromSqlRaw("[dbo].[Report_VendorPurchaseSummary] @IncludeClosed", IncludeClosedParam);
        }

        public IQueryable<RptCustomerSalesSummary> CustomerSalesSummary(bool includeClosed, int? salesRepId)
        {
            var IncludeClosedParam = new SqlParameter("@IncludeClosed", includeClosed);
            var SalesRepIdParam = salesRepId.HasValue
                ? new SqlParameter("@SalesRepId", salesRepId.Value)
                : new SqlParameter("@SalesRepId", DBNull.Value);

            return DbContext.RptCustomerSalesSummary.FromSqlRaw(
                "[dbo].[Report_CustomerSalesSummary] @IncludeClosed, @SalesRepId",
                IncludeClosedParam,
                SalesRepIdParam);
        }

        public IQueryable<RptSalesSummary> SalesSummary(string grain, DateOnly? startDate, DateOnly? endDate, int? salesRepId)
        {
            var GrainParam     = new SqlParameter("@Grain", string.IsNullOrWhiteSpace(grain) ? "month" : grain);
            var StartDateParam = startDate.HasValue
                ? new SqlParameter("@StartDate", startDate.Value)
                : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam   = endDate.HasValue
                ? new SqlParameter("@EndDate", endDate.Value)
                : new SqlParameter("@EndDate", DBNull.Value);
            var SalesRepIdParam = salesRepId.HasValue
                ? new SqlParameter("@SalesRepId", salesRepId.Value)
                : new SqlParameter("@SalesRepId", DBNull.Value);

            return DbContext.RptSalesSummary.FromSqlRaw(
                "[dbo].[Report_SalesSummary] @Grain, @StartDate, @EndDate, @SalesRepId",
                GrainParam, StartDateParam, EndDateParam, SalesRepIdParam);
        }

        public IQueryable<RptResponsibleRow>? Responsible(DateOnly? ShipDate)
        {
            var ShipDateParam = ShipDate.HasValue ? new SqlParameter("@ShipDate", ShipDate) : new SqlParameter("@ShipDate", DBNull.Value);

            return DbContext.RptResponsibleRow.FromSqlRaw("[dbo].[Report_Responsible] @ShipDate", ShipDateParam);
        }

        public IQueryable<RptDailySummaryRow>? DailySummary(DateOnly? ShipDate)
        {
            var ShipDateParam = ShipDate.HasValue ? new SqlParameter("@ShipDate", ShipDate) : new SqlParameter("@ShipDate", DBNull.Value);

            return DbContext.RptDailySummaryRow.FromSqlRaw("[dbo].[Report_DailySummary] @ShipDate", ShipDateParam);
        }

        public IQueryable<RptPricesheet> Pricesheet(int payeeId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            return DbContext.RptPricesheet.FromSqlRaw("[dbo].[Report_PriceSheet] @PayeeId", PayeeIdParam);
        }

        public IQueryable<RptOrderGuideItem> OrderGuide(int payeeId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            return DbContext.RptOrderGuideItem.FromSqlRaw("[dbo].[Report_OrderGuide] @PayeeId", PayeeIdParam);
        }

        public IQueryable<RptCustItemVolume> CustItemVolume(int payeeId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            return DbContext.RptCustItemVolume.FromSqlRaw("[dbo].[Report_CustItemVolume] @PayeeId", PayeeIdParam);
        }

        public IQueryable<CustBoughtItemPanelRow> CustBoughtItemsPanel(int payeeId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            return DbContext.CustBoughtItemPanelRows.FromSqlRaw("[dbo].[CustBoughtItems_GetPanel] @PayeeId", PayeeIdParam);
        }

        public IQueryable<VendorPurchaseHistoryPanelRow> VendorPurchaseHistoryPanel(int payeeId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            return DbContext.VendorPurchaseHistoryPanelRows.FromSqlRaw("[dbo].[VendorPurchaseHistory_GetPanel] @PayeeId", PayeeIdParam);
        }

        public IQueryable<RptCustSalesByItem>? CustSalesByItem(ReportRequest reportReq)
        {
            var SearchParam = string.IsNullOrEmpty(reportReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", reportReq.Search);
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var GrpbycatParam = new SqlParameter("@Grpbycat", false);
            var SortbyParam = string.IsNullOrEmpty(reportReq.SortField) ? new SqlParameter("@Sortby", DBNull.Value) : new SqlParameter("@Sortby", reportReq.SortField);

            return DbContext.RptCustSalesByItem.FromSqlRaw("[dbo].[Report_CustSalesbyItem] @Search,@StartDate,@EndDate,@Grpbycat,@Sortby",
                SearchParam, StartDateParam, EndDateParam, GrpbycatParam, SortbyParam);
        }

        public IQueryable<RptSalesHistoryRow> SalesHistory(ReportRequest reportReq)
        {
            var PayeeIdParam = reportReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", reportReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            return DbContext.RptSalesHistoryRow.FromSqlRaw("[dbo].[Report_SalesHistory] @PayeeId,@StartDate,@EndDate",
                PayeeIdParam, StartDateParam, EndDateParam);
        }

        public IQueryable<RptPurchaseHistoryRow> PurchaseHistory(ReportRequest reportReq)
        {
            var PayeeIdParam = reportReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", reportReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            return DbContext.RptPurchaseHistoryRow.FromSqlRaw("[dbo].[Report_PurchaseHistory] @PayeeId,@StartDate,@EndDate",
                PayeeIdParam, StartDateParam, EndDateParam);
        }

        public IQueryable<RptItemCustomerAnalysisRow> ItemCustomerAnalysis(ItemCustomerAnalysisRequest reportReq)
        {
            var ItemIdParam    = new SqlParameter("@ItemId", reportReq.ItemId);
            var PayeeIdParam   = reportReq.PayeeId.HasValue   ? new SqlParameter("@PayeeId",   reportReq.PayeeId)   : new SqlParameter("@PayeeId",   DBNull.Value);
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam   = reportReq.EndDate.HasValue   ? new SqlParameter("@EndDate",   reportReq.EndDate)   : new SqlParameter("@EndDate",   DBNull.Value);

            return DbContext.RptItemCustomerAnalysisRow.FromSqlRaw("[dbo].[Report_ItemCustomerAnalysis] @ItemId,@PayeeId,@StartDate,@EndDate",
                ItemIdParam, PayeeIdParam, StartDateParam, EndDateParam);
        }

        public IQueryable<RptItemVendorAnalysisRow> ItemVendorAnalysis(ItemCustomerAnalysisRequest reportReq)
        {
            var ItemIdParam    = new SqlParameter("@ItemId", reportReq.ItemId);
            var PayeeIdParam   = reportReq.PayeeId.HasValue   ? new SqlParameter("@PayeeId",   reportReq.PayeeId)   : new SqlParameter("@PayeeId",   DBNull.Value);
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam   = reportReq.EndDate.HasValue   ? new SqlParameter("@EndDate",   reportReq.EndDate)   : new SqlParameter("@EndDate",   DBNull.Value);

            return DbContext.RptItemVendorAnalysisRow.FromSqlRaw("[dbo].[Report_ItemVendorAnalysis] @ItemId,@PayeeId,@StartDate,@EndDate",
                ItemIdParam, PayeeIdParam, StartDateParam, EndDateParam);
        }

        public IQueryable<RptItemAnalysis> ItemAnalysis(ItemAnalysisRequest reportReq)
        {
            var SearchParam     = string.IsNullOrEmpty(reportReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", reportReq.Search);
            var CategoryIdParam = reportReq.CategoryId.HasValue ? new SqlParameter("@CategoryId", reportReq.CategoryId) : new SqlParameter("@CategoryId", DBNull.Value);
            var StartDateParam  = reportReq.StartDate.HasValue  ? new SqlParameter("@StartDate",  reportReq.StartDate)  : new SqlParameter("@StartDate",  DBNull.Value);
            var EndDateParam    = reportReq.EndDate.HasValue    ? new SqlParameter("@EndDate",    reportReq.EndDate)    : new SqlParameter("@EndDate",    DBNull.Value);
            // default grouping to 'category' when the caller omits it (the SP default doesn't apply via positional FromSqlRaw)
            var GroupByParam    = new SqlParameter("@GroupBy", string.IsNullOrEmpty(reportReq.GroupBy) ? "category" : reportReq.GroupBy);
            // SortField maps to the SP's @Sortby (mostordered | itemname | sales | expiry)
            var SortbyParam     = string.IsNullOrEmpty(reportReq.SortField) ? new SqlParameter("@Sortby", DBNull.Value) : new SqlParameter("@Sortby", reportReq.SortField);

            return DbContext.RptItemAnalysis.FromSqlRaw("[dbo].[Report_ItemAnalysis] @Search,@CategoryId,@StartDate,@EndDate,@GroupBy,@Sortby",
                SearchParam, CategoryIdParam, StartDateParam, EndDateParam, GroupByParam, SortbyParam);
        }

        public IQueryable<RptCustPayment> CustPayment(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var PayeeIdParam = reportReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", reportReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);
            var PmtMethodParam = string.IsNullOrEmpty(reportReq.Search) ? new SqlParameter("@PmtMethod", DBNull.Value) : new SqlParameter("@PmtMethod", reportReq.Search);

            return DbContext.RptCustPayment.FromSqlRaw("[dbo].[Report_CustomerPayment] @StartDate,@EndDate,@PayeeId,@PmtMethod",
                StartDateParam, EndDateParam, PayeeIdParam, PmtMethodParam);
        }

        public IQueryable<RptCreditMemo> CreditMemo(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var SalesRepParam = reportReq.SalesRepId.HasValue ? new SqlParameter("@SalesRep", reportReq.SalesRepId) : new SqlParameter("@SalesRep", DBNull.Value);

            return DbContext.RptCreditMemo.FromSqlRaw("[dbo].[Report_CreditMemo] @StartDate,@EndDate,@SalesRep", StartDateParam, EndDateParam, SalesRepParam);
        }

        public IQueryable<RptSalesDaily>? SalesDaily(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);

            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            var SalesRepIdParam = reportReq.SalesRepId.HasValue ? new SqlParameter("@SalesRepId", reportReq.SalesRepId) : new SqlParameter("@SalesRepId", DBNull.Value);

            return DbContext.RptSalesDaily.FromSqlRaw("[dbo].[Report_SalesDaily] @StartDate,@EndDate,@SalesRepId", StartDateParam, EndDateParam, SalesRepIdParam);
        }

        public IQueryable<RptLedgerRow> Ledger(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var AccountIdParam = reportReq.AccountId.HasValue ? new SqlParameter("@AccountId", reportReq.AccountId) : new SqlParameter("@AccountId", DBNull.Value);

            return DbContext.RptLedgerRow.FromSqlRaw("[dbo].[Report_Ledger] @StartDate,@EndDate,@AccountId", StartDateParam, EndDateParam, AccountIdParam);
        }

        public IQueryable<RptAccountHistory> AccountHistory(int payeeId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            return DbContext.RptAccountHistory.FromSqlRaw("[dbo].[Report_AccountHistory] @PayeeId", PayeeIdParam);
        }

        public IQueryable<RptJobSummary> JobSummary(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            return DbContext.RptJobSummary.FromSqlRaw("[dbo].[Report_JobSummary] @StartDate,@EndDate", StartDateParam, EndDateParam);
        }

        public IQueryable<RptPayroll> Payroll(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var PayeeIdParam = reportReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", reportReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);
            var PmtMethodParam = string.IsNullOrEmpty(reportReq.Search) ? new SqlParameter("@PmtMethod", DBNull.Value) : new SqlParameter("@PmtMethod", reportReq.Search);

            return DbContext.RptPayroll.FromSqlRaw("[dbo].[Report_Payroll] @StartDate,@EndDate,@PayeeId,@PmtMethod",
                StartDateParam, EndDateParam, PayeeIdParam, PmtMethodParam);
        }

        public IQueryable<RptEmpLoanLedger> EmpLoanLedger(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var PayeeIdParam = reportReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", reportReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);

            return DbContext.RptEmpLoanLedger.FromSqlRaw("[dbo].[Report_LedgerEmpLoan] @StartDate,@EndDate,@PayeeId",
                StartDateParam, EndDateParam, PayeeIdParam);
        }

        public IQueryable<RptLedgerByPayeeRow> LedgerByPayee(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var PayeeIdParam = reportReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", reportReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);

            return DbContext.RptLedgerByPayeeRow.FromSqlRaw("[dbo].[Report_LedgerByPayee] @StartDate,@EndDate,@PayeeId",
                StartDateParam, EndDateParam, PayeeIdParam);
        }

        public IQueryable<RptBankReconRow> BankRecon(int bankReconId)
        {
            var BankReconIdParam = new SqlParameter("@BankReconId", bankReconId);

            return DbContext.RptBankReconRow.FromSqlRaw("[dbo].[Report_BankRecon] @BankReconId", BankReconIdParam);
        }

        public IQueryable<RptAPCheckRow> APCheck(ReportRequest reportReq)
        {
            var FilterbyParam = string.IsNullOrEmpty(reportReq.Search) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", reportReq.Search);

            return DbContext.RptAPCheckRow.FromSqlRaw("[dbo].[Report_Check] @Filterby", FilterbyParam);
        }

        public IQueryable<RptCheckToBePrintedRow> CheckToBePrinted(string? pmtMethod)
        {
            var PmtMethodParam = string.IsNullOrEmpty(pmtMethod) ? new SqlParameter("@PmtMethod", DBNull.Value) : new SqlParameter("@PmtMethod", pmtMethod);

            return DbContext.RptCheckToBePrintedRow.FromSqlRaw("[dbo].[Report_CheckToBePrinted] @PmtMethod", PmtMethodParam);
        }

        public IQueryable<RptAPInvoiceRow> APInvoice(ReportRequest reportReq)
        {
            var TermParam = string.IsNullOrEmpty(reportReq.Search) ? new SqlParameter("@Term", DBNull.Value) : new SqlParameter("@Term", reportReq.Search);
            var SortbyParam = string.IsNullOrEmpty(reportReq.SortField) ? new SqlParameter("@Sortby", DBNull.Value) : new SqlParameter("@Sortby", reportReq.SortField);
            var FilterbyParam = string.IsNullOrEmpty(reportReq.SortOrder) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", reportReq.SortOrder);

            return DbContext.RptAPInvoiceRow.FromSqlRaw("[dbo].[Report_APFromInvoice] @Term,@Sortby,@Filterby",
                TermParam, SortbyParam, FilterbyParam);
        }

        public IQueryable<RptAPAgingRow> APAging(RptAPAgingReq req)
        {
            var AsOfDateParam = req.AsOfDate.HasValue ? new SqlParameter("@AsOfDate", req.AsOfDate.Value) : new SqlParameter("@AsOfDate", DBNull.Value);
            var AgeBasisParam = new SqlParameter("@AgeBasis", string.IsNullOrEmpty(req.AgeBasis) ? "DueDate" : req.AgeBasis);
            var VendorIdParam = req.VendorId.HasValue ? new SqlParameter("@VendorId", req.VendorId.Value) : new SqlParameter("@VendorId", DBNull.Value);
            var TermIdParam   = req.TermId.HasValue   ? new SqlParameter("@TermId",   req.TermId.Value)   : new SqlParameter("@TermId",   DBNull.Value);

            return DbContext.RptAPAgingRow.FromSqlRaw(
                "[dbo].[Report_APAging] @AsOfDate,@AgeBasis,@VendorId,@TermId",
                AsOfDateParam, AgeBasisParam, VendorIdParam, TermIdParam);
        }

        public IQueryable<RptARAgingRow> ARAging(RptARAgingReq req)
        {
            var AsOfDateParam   = req.AsOfDate.HasValue   ? new SqlParameter("@AsOfDate", req.AsOfDate.Value)     : new SqlParameter("@AsOfDate", DBNull.Value);
            var AgeBasisParam   = new SqlParameter("@AgeBasis", string.IsNullOrEmpty(req.AgeBasis) ? "DueDate" : req.AgeBasis);
            var CustomerIdParam = req.CustomerId.HasValue ? new SqlParameter("@CustomerId", req.CustomerId.Value) : new SqlParameter("@CustomerId", DBNull.Value);
            var TermIdParam     = req.TermId.HasValue     ? new SqlParameter("@TermId",     req.TermId.Value)     : new SqlParameter("@TermId",     DBNull.Value);
            var SalesRepIdParam = req.SalesRepId.HasValue ? new SqlParameter("@SalesRepId", req.SalesRepId.Value) : new SqlParameter("@SalesRepId", DBNull.Value);

            return DbContext.RptARAgingRow.FromSqlRaw(
                "[dbo].[Report_ARAging] @AsOfDate,@AgeBasis,@CustomerId,@TermId,@SalesRepId",
                AsOfDateParam, AgeBasisParam, CustomerIdParam, TermIdParam, SalesRepIdParam);
        }

        public IQueryable<RptSalesDetailRow> SalesDetail(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var ItemCodeParam = string.IsNullOrEmpty(reportReq.Search) ? new SqlParameter("@ItemCode", DBNull.Value) : new SqlParameter("@ItemCode", reportReq.Search);
            var SalesRepParam = reportReq.SalesRepId.HasValue ? new SqlParameter("@SalesRep", reportReq.SalesRepId) : new SqlParameter("@SalesRep", DBNull.Value);

            return DbContext.RptSalesDetailRow.FromSqlRaw("[dbo].[Report_SalesDetail] @StartDate,@EndDate,@ItemCode,@SalesRep",
                StartDateParam, EndDateParam, ItemCodeParam, SalesRepParam);
        }

        public IQueryable<RptSalesDaily2Row> SalesDaily2(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var SalesRepParam = reportReq.SalesRepId.HasValue ? new SqlParameter("@SalesRep", reportReq.SalesRepId) : new SqlParameter("@SalesRep", DBNull.Value);

            return DbContext.RptSalesDaily2Row.FromSqlRaw("[dbo].[Report_SalesDaily2] @StartDate,@EndDate,@SalesRep",
                StartDateParam, EndDateParam, SalesRepParam);
        }

        public IQueryable<RptSalesByInvoiceRow> SalesByInvoice(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var SalesRepParam = reportReq.SalesRepId.HasValue ? new SqlParameter("@SalesRep", reportReq.SalesRepId) : new SqlParameter("@SalesRep", DBNull.Value);

            return DbContext.RptSalesByInvoiceRow.FromSqlRaw("[dbo].[Report_SalesByInvoice] @StartDate,@EndDate,@SalesRep",
                StartDateParam, EndDateParam, SalesRepParam);
        }

        public IQueryable<RptSalesYearlyRow> SalesYearly()
        {
            return DbContext.RptSalesYearlyRow.FromSqlRaw("[dbo].[Report_SalesYearly]");
        }

        public IQueryable<RptSalesCommissionRow> SalesCommission(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var SalesRepParam = reportReq.SalesRepId.HasValue ? new SqlParameter("@SalesRep", reportReq.SalesRepId) : new SqlParameter("@SalesRep", DBNull.Value);

            return DbContext.RptSalesCommissionRow.FromSqlRaw("[dbo].[Report_SalesCommission] @StartDate,@EndDate,@SalesRep",
                StartDateParam, EndDateParam, SalesRepParam);
        }

        public IQueryable<RptSalesCommission2Row> SalesCommission2(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var SalesRepParam = reportReq.SalesRepId.HasValue ? new SqlParameter("@SalesRep", reportReq.SalesRepId) : new SqlParameter("@SalesRep", DBNull.Value);

            return DbContext.RptSalesCommission2Row.FromSqlRaw("[dbo].[Report_SalesCommission2] @StartDate,@EndDate,@SalesRep",
                StartDateParam, EndDateParam, SalesRepParam);
        }

        public IQueryable<RptSalesCommission3Row> SalesCommission3(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var SalesRepParam = reportReq.SalesRepId.HasValue ? new SqlParameter("@SalesRep", reportReq.SalesRepId) : new SqlParameter("@SalesRep", DBNull.Value);

            return DbContext.RptSalesCommission3Row.FromSqlRaw("[dbo].[Report_SalesCommission3] @StartDate,@EndDate,@SalesRep",
                StartDateParam, EndDateParam, SalesRepParam);
        }

        public IQueryable<RptARInvoiceRow> ARInvoice(ReportRequest reportReq)
        {
            var TermParam = string.IsNullOrEmpty(reportReq.Search) ? new SqlParameter("@Term", DBNull.Value) : new SqlParameter("@Term", reportReq.Search);
            var SortbyParam = string.IsNullOrEmpty(reportReq.SortField) ? new SqlParameter("@Sortby", DBNull.Value) : new SqlParameter("@Sortby", reportReq.SortField);
            var FilterbyParam = string.IsNullOrEmpty(reportReq.SortOrder) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", reportReq.SortOrder);
            var SalesRepParam = reportReq.SalesRepId.HasValue ? new SqlParameter("@SalesRep", reportReq.SalesRepId) : new SqlParameter("@SalesRep", DBNull.Value);

            return DbContext.RptARInvoiceRow.FromSqlRaw("[dbo].[Report_ARFromInvoice] @Term,@Sortby,@Filterby,@SalesRep",
                TermParam, SortbyParam, FilterbyParam, SalesRepParam);
        }

        public IQueryable<RptARMonthRow> ARMonth(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var SalesRepParam = reportReq.SalesRepId.HasValue ? new SqlParameter("@SalesRep", reportReq.SalesRepId) : new SqlParameter("@SalesRep", DBNull.Value);
            var SortByParam = string.IsNullOrEmpty(reportReq.SortField) ? new SqlParameter("@SortBy", DBNull.Value) : new SqlParameter("@SortBy", reportReq.SortField);

            return DbContext.RptARMonthRow.FromSqlRaw("[dbo].[Report_ARMonth] @StartDate,@EndDate,@SalesRep,@SortBy",
                StartDateParam, EndDateParam, SalesRepParam, SortByParam);
        }

        public IQueryable<RptARRollforward> ARRollforward(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var PayeeIdParam = reportReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", reportReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);

            return DbContext.RptARRollforward.FromSqlRaw("[dbo].[Report_ARRollforward] @StartDate,@EndDate,@PayeeId",
                StartDateParam, EndDateParam, PayeeIdParam);
        }

        public IQueryable<RptDescDollar>? DescDollar(ReportRequest reportReq)
        {
            var PayeeIdParam = reportReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", reportReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);

            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);

            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            var SortFieldParam = string.IsNullOrEmpty(reportReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", reportReq.SortField);

            var SortOrderParam = string.IsNullOrEmpty(reportReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", reportReq.SortOrder);

            return DbContext.RptDescDollar.FromSqlRaw("[dbo].[Report_DescDollar] @PayeeId,@StartDate,@EndDate,@SortField,@SortOrder", PayeeIdParam, StartDateParam, EndDateParam, SortFieldParam, SortOrderParam);
        }

        public IQueryable<RptDescDollar>? VendorDescDollar(ReportRequest reportReq)
        {
            var PayeeIdParam = reportReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", reportReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);

            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);

            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            var SortFieldParam = string.IsNullOrEmpty(reportReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", reportReq.SortField);

            var SortOrderParam = string.IsNullOrEmpty(reportReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", reportReq.SortOrder);

            return DbContext.RptDescDollar.FromSqlRaw("[dbo].[Report_VendorDescDollar] @PayeeId,@StartDate,@EndDate,@SortField,@SortOrder", PayeeIdParam, StartDateParam, EndDateParam, SortFieldParam, SortOrderParam);
        }

        #region --- Inventory Reports ---

        public IQueryable<RptInventoryStatusRow> InventoryStatus(InventoryReportRequest req)
        {
            var searchParam = !string.IsNullOrEmpty(req.Search) ? new SqlParameter("@Search", req.Search) : new SqlParameter("@Search", DBNull.Value);
            var catParam = req.CategoryId.HasValue ? new SqlParameter("@CategoryId", req.CategoryId) : new SqlParameter("@CategoryId", DBNull.Value);
            var zoneParam = !string.IsNullOrEmpty(req.Zone) ? new SqlParameter("@Zone", req.Zone) : new SqlParameter("@Zone", DBNull.Value);
            var inactiveParam = new SqlParameter("@ShowInactive", req.ShowInactive ?? false);
            var payeeParam = req.PayeeId.HasValue ? new SqlParameter("@PayeeId", req.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);

            return DbContext.RptInventoryStatusRow.FromSqlRaw(
                "[dbo].[Report_InventoryStatus] @Search,@CategoryId,@Zone,@ShowInactive,@PayeeId",
                searchParam, catParam, zoneParam, inactiveParam, payeeParam);
        }

        public IQueryable<RptReorderRow> Reorder(InventoryReportRequest req)
        {
            var catParam = req.CategoryId.HasValue ? new SqlParameter("@CategoryId", req.CategoryId) : new SqlParameter("@CategoryId", DBNull.Value);
            var zoneParam = !string.IsNullOrEmpty(req.Zone) ? new SqlParameter("@Zone", req.Zone) : new SqlParameter("@Zone", DBNull.Value);
            var payeeParam = req.PayeeId.HasValue ? new SqlParameter("@PayeeId", req.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);

            return DbContext.RptReorderRow.FromSqlRaw(
                "[dbo].[Report_Reorder] @CategoryId,@Zone,@PayeeId",
                catParam, zoneParam, payeeParam);
        }

        public IQueryable<RptInventoryValuationRow> InventoryValuation(InventoryReportRequest req)
        {
            var catParam = req.CategoryId.HasValue ? new SqlParameter("@CategoryId", req.CategoryId) : new SqlParameter("@CategoryId", DBNull.Value);
            var zoneParam = !string.IsNullOrEmpty(req.Zone) ? new SqlParameter("@Zone", req.Zone) : new SqlParameter("@Zone", DBNull.Value);
            var payeeParam = req.PayeeId.HasValue ? new SqlParameter("@PayeeId", req.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);

            return DbContext.RptInventoryValuationRow.FromSqlRaw(
                "[dbo].[Report_InventoryValuation] @CategoryId,@Zone,@PayeeId",
                catParam, zoneParam, payeeParam);
        }

        public IQueryable<RptInventoryMovementRow> InventoryMovement(InventoryReportRequest req)
        {
            var catParam = req.CategoryId.HasValue ? new SqlParameter("@CategoryId", req.CategoryId) : new SqlParameter("@CategoryId", DBNull.Value);
            var zoneParam = !string.IsNullOrEmpty(req.Zone) ? new SqlParameter("@Zone", req.Zone) : new SqlParameter("@Zone", DBNull.Value);
            var expiryParam = new SqlParameter("@ShowExpiry", req.ShowExpiry ?? false);
            var payeeParam = req.PayeeId.HasValue ? new SqlParameter("@PayeeId", req.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);

            return DbContext.RptInventoryMovementRow.FromSqlRaw(
                "[dbo].[Report_InventoryMovement] @CategoryId,@Zone,@ShowExpiry,@PayeeId",
                catParam, zoneParam, expiryParam, payeeParam);
        }

        public IQueryable<RptInventoryIncomingRow> InventoryIncoming()
        {
            return DbContext.RptInventoryIncomingRow.FromSqlRaw("[dbo].[Report_InventoryIncoming]");
        }

        public IQueryable<RptWorksheet> WorksheetPattern(WorksheetPatternReportRequest req)
        {
            var searchParam = !string.IsNullOrEmpty(req.Search) ? new SqlParameter("@Search", req.Search) : new SqlParameter("@Search", DBNull.Value);
            var payeeParam = req.PayeeId.HasValue ? new SqlParameter("@PayeeId", req.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value);
            var filterbyParam = !string.IsNullOrEmpty(req.Filterby) ? new SqlParameter("@Filterby", req.Filterby) : new SqlParameter("@Filterby", DBNull.Value);
            var categoryParam = req.CategoryId.HasValue ? new SqlParameter("@Category", req.CategoryId.Value.ToString()) : new SqlParameter("@Category", DBNull.Value);
            var inactiveParam = new SqlParameter("@Inactive", req.ShowInactive ?? false);

            return DbContext.RptWorksheet.FromSqlRaw(
                "[dbo].[Report_WorkSheetPattern] @Search,@PayeeId,@Filterby,@Category,@Inactive",
                searchParam, payeeParam, filterbyParam, categoryParam, inactiveParam);
        }

        #endregion

        public RptCheckPrint? CheckPrint(int vendorPaymentId)
        {
            var param = new SqlParameter("@VendorPaymentId", vendorPaymentId);
            return DbContext.RptCheckPrint
                .FromSqlRaw("[dbo].[Report_CheckPrint] @VendorPaymentId", param)
                .AsEnumerable().FirstOrDefault();
        }

        public IQueryable<RptCheckPrintDetail> CheckPrintDetail(int vendorPaymentId)
        {
            var param = new SqlParameter("@VendorPaymentId", vendorPaymentId);
            return DbContext.RptCheckPrintDetail
                .FromSqlRaw("[dbo].[Report_CheckPrintDetail] @VendorPaymentId", param);
        }

        public IQueryable<InvoiceDetail>? SalesQuoteDetail(int salesQuoteId)
        {
            var param = new SqlParameter("@SalesQuoteId", salesQuoteId);
            return DbContext.InvoiceDetail
                .FromSqlRaw("[dbo].[Report_SalesQuote] @SalesQuoteId", param).AsNoTracking();
        }

        public IQueryable<RptMarketOrder> MarketOrder(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);
            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);
            var AccountIdParam = reportReq.AccountId.HasValue ? new SqlParameter("@AccountId", reportReq.AccountId) : new SqlParameter("@AccountId", DBNull.Value);

            return DbContext.RptMarketOrder.FromSqlRaw("[dbo].[Report_MarketOrder] @StartDate,@EndDate,@AccountId",
                StartDateParam, EndDateParam, AccountIdParam);
        }
    }
}
