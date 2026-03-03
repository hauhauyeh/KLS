using KLS.Models;
using KLS.Models.Reports;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IReportRepository : IRepository<RptPOView>
    {
        Invoice Invoice(int salesId);

        IQueryable<InvoiceDetail>? InvoiceDetail(int salesId);

        RptCustStmt CustStmt(int payeeId);

        RptPO ReportPO(int purchaseId);

        IQueryable<RptPODetail> ReportPODetail(int purchaseId);

        IQueryable<RptPackingItem> PackingList(DocumentReq req);

        IQueryable<RptHarvillsItem> Harvills(DateOnly shipDate);

        IQueryable<RptStoreTotalItem> StoreTotal(DateOnly shipDate);

        IQueryable<RptSensitiveItem> Sensitive(DateOnly shipDate);

        IQueryable<RptAssignTruck> AssignTruck(DateOnly shipDate);

        IQueryable<RptLoadingItem> LoadingList(DocumentReq req);

        IQueryable<RptPackingLabel> PackingLabel(DocumentReq req);

        IQueryable<RptBalanceSheetRow> BalanceSheet(DateOnly? endDate);

        IQueryable<RptProfitLossRow> ProfitLoss(ReportRequest reportReq);

        IQueryable<RptSalesTax>? SalesTax(ReportRequest reportReq);

        IQueryable<RptResponsibleRow>? Responsible(DateOnly? ShipDate);

        IQueryable<RptDailySummaryRow>? DailySummary(DateOnly? ShipDate);

        IQueryable<RptPricesheet> Pricesheet(int payeeId);

        IQueryable<RptSalesDaily>? SalesDaily(ReportRequest reportReq);

        IQueryable<RptDescDollar>? DescDollar(ReportRequest reportReq);
    }
}
