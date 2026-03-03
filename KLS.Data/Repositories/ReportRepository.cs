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

        public RptCustStmt CustStmt(int payeeId)
        {
            var details = DbContext.Sales.Where(s => s.ShipId == payeeId && s.AmountDue != 0)
                .GroupBy(s => new { s.ShipDate.Value.Year, s.ShipDate.Value.Month })
                .Select(g => new RptCustStmtDetail
                {
                    ShipMonth = new DateTimeFormatInfo().GetMonthName(g.Key.Month) + " - " + g.Key.Year.ToString(),
                    Sales = g.OrderBy(s => s.ShipDate).ToList()
                }).ToList();

            var customer = DbContext.Customers.Find(payeeId);

            return new RptCustStmt
            {
                Details = details,
                Payee = DbContext.Payees.Find(payeeId),
                IsPromotionEnabled = customer.IsPromotionEnabled,
                AvailableCredit = DbContext.CustomerPayments.Where(c => c.PayeeId == payeeId && c.UnappliedAmount != 0 && c.IsReturned == false).ToList()
            };
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

        public IQueryable<RptSalesDaily>? SalesDaily(ReportRequest reportReq)
        {
            var StartDateParam = reportReq.StartDate.HasValue ? new SqlParameter("@StartDate", reportReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);

            var EndDateParam = reportReq.EndDate.HasValue ? new SqlParameter("@EndDate", reportReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            var SalesRepIdParam = reportReq.SalesRepId.HasValue ? new SqlParameter("@SalesRepId", reportReq.SalesRepId) : new SqlParameter("@SalesRepId", DBNull.Value);

            return DbContext.RptSalesDaily.FromSqlRaw("[dbo].[Report_SalesDaily] @StartDate,@EndDate,@SalesRepId", StartDateParam, EndDateParam, SalesRepIdParam);
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
    }
}
