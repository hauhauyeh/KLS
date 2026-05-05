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

        IQueryable<RptServiceSummary> ServiceSummary(ReportRequest reportReq);

        IQueryable<RptSalesCallListRow> SalesCallList();

        IQueryable<RptResponsibleRow>? Responsible(DateOnly? ShipDate);

        IQueryable<RptDailySummaryRow>? DailySummary(DateOnly? ShipDate);

        IQueryable<RptPricesheet> Pricesheet(int payeeId);

        IQueryable<RptSalesDaily>? SalesDaily(ReportRequest reportReq);

        IQueryable<RptDescDollar>? DescDollar(ReportRequest reportReq);

        IQueryable<RptLedgerRow> Ledger(ReportRequest reportReq);

        IQueryable<RptAccountHistory> AccountHistory(int payeeId);

        IQueryable<RptOrderGuideItem> OrderGuide(int payeeId);

        IQueryable<RptCustItemVolume> CustItemVolume(int payeeId);

        IQueryable<CustBoughtItemPanelRow> CustBoughtItemsPanel(int payeeId);

        IQueryable<RptCustSalesByItem>? CustSalesByItem(ReportRequest reportReq);

        IQueryable<RptSalesHistoryRow> SalesHistory(ReportRequest reportReq);

        IQueryable<RptCustPayment> CustPayment(ReportRequest reportReq);

        IQueryable<RptCreditMemo> CreditMemo(ReportRequest reportReq);

        IQueryable<RptJobSummary> JobSummary(ReportRequest reportReq);

        IQueryable<RptPayroll> Payroll(ReportRequest reportReq);

        IQueryable<RptEmpLoanLedger> EmpLoanLedger(ReportRequest reportReq);

        IQueryable<RptARInvoiceRow> ARInvoice(ReportRequest reportReq);

        IQueryable<RptARMonthRow> ARMonth(ReportRequest reportReq);

        IQueryable<RptSalesCommissionRow> SalesCommission(ReportRequest reportReq);

        IQueryable<RptSalesCommission2Row> SalesCommission2(ReportRequest reportReq);

        IQueryable<RptSalesDaily2Row> SalesDaily2(ReportRequest reportReq);

        IQueryable<RptSalesByInvoiceRow> SalesByInvoice(ReportRequest reportReq);

        IQueryable<RptSalesYearlyRow> SalesYearly();

        IQueryable<RptSalesDetailRow> SalesDetail(ReportRequest reportReq);

        IQueryable<RptLedgerByPayeeRow> LedgerByPayee(ReportRequest reportReq);

        IQueryable<RptBankReconRow> BankRecon(int bankReconId);

        IQueryable<RptAPCheckRow> APCheck(ReportRequest reportReq);

        IQueryable<RptCheckToBePrintedRow> CheckToBePrinted(string? pmtMethod);

        IQueryable<RptAPInvoiceRow> APInvoice(ReportRequest reportReq);

        IQueryable<RptInventoryStatusRow> InventoryStatus(InventoryReportRequest req);

        IQueryable<RptReorderRow> Reorder(InventoryReportRequest req);

        IQueryable<RptInventoryValuationRow> InventoryValuation(InventoryReportRequest req);

        IQueryable<RptInventoryMovementRow> InventoryMovement(InventoryReportRequest req);

        IQueryable<RptInventoryIncomingRow> InventoryIncoming();

        IQueryable<RptWorksheet> WorksheetPattern(WorksheetPatternReportRequest req);
    }
}
