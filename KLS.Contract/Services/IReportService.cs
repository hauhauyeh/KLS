using KLS.Models;
using KLS.Models.Reports;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IReportService
    {
        RptInvoice Invoice(int salesId);

        RptCustStmt CustStmt(int payeeId);

        RptPackingList PackingList(DocumentReq req);

        // TotalSplit is a new standalone packing-style report that can split
        // outer boxes for lbs rows coming from different source sales.
        RptPackingList TotalSplitPacking(DocumentReq req);

        // These filtered packing-style reports intentionally reuse the standalone
        // PackingList layout instead of the legacy Harvills / Store Total layouts.
        RptPackingList HarvillsPacking(DateOnly shipDate);

        RptPackingList StoreTotalPacking(DateOnly shipDate);

        IEnumerable<RptBalanceSheet>? BalanceSheet(DateOnly? endDate);

        IEnumerable<RptProfitLoss>? ProfitLoss(ReportRequest reportReq);

        IEnumerable<RptSalesTax>? SalesTax(ReportRequest reportReq);

        IEnumerable<RptResponsible> Responsible(DateOnly? shipDate);

        List<RptDailySummary> DailySummary(DateOnly? shipDate);

        IEnumerable<RptSalesDaily>? SalesDaily(ReportRequest reportReq);

        IEnumerable<RptDescDollar>? DescDollar(ReportRequest reportReq);

        IEnumerable<RptPaymentHistory>? PaymentHistory(int payeeId);

        RptLedger? Ledger(ReportRequest reportReq);

        IEnumerable<RptAccountHistory>? AccountHistory(int payeeId);

        IQueryable<RptPricesheet> Pricesheet(int payeeId);

        IQueryable<RptOrderGuideItem> OrderGuide(int payeeId);

        IQueryable<RptCustItemVolume> CustItemVolume(int payeeId);

        IEnumerable<RptCustSalesByItem>? CustSalesByItem(ReportRequest reportReq);

        IQueryable<RptSalesHistoryRow> SalesHistory(ReportRequest reportReq);

        IQueryable<RptCustPayment> CustPayment(ReportRequest reportReq);

        IQueryable<RptCreditMemo> CreditMemo(ReportRequest reportReq);

        IQueryable<RptJobSummary> JobSummary(ReportRequest reportReq);

        IQueryable<RptPayroll> Payroll(ReportRequest reportReq);

        IQueryable<RptEmpLoanLedger> EmpLoanLedger(ReportRequest reportReq);

        IQueryable<RptLedgerByPayeeRow> LedgerByPayee(ReportRequest reportReq);

        RptBankRecon BankRecon(int bankReconId);

        IQueryable<RptAPCheckRow> APCheck(ReportRequest reportReq);

        IQueryable<RptCheckToBePrintedRow> CheckToBePrinted(string? pmtMethod);

        RptARInvoice APInvoice(ReportRequest reportReq);

        IQueryable<RptSalesDetailRow> SalesDetail(ReportRequest reportReq);

        IQueryable<RptSalesDaily2Row> SalesDaily2(ReportRequest reportReq);

        RptSalesYearly SalesYearly();

        IQueryable<RptSalesCommissionRow> SalesCommission(ReportRequest reportReq);

        IQueryable<RptSalesCommission2Row> SalesCommission2(ReportRequest reportReq);

        RptARInvoice ARInvoice(ReportRequest reportReq);

        RptARMonth ARMonth(ReportRequest reportReq);

        IEnumerable<RptInventoryStatusRow> InventoryStatus(InventoryReportRequest req);

        IEnumerable<RptReorderRow> Reorder(InventoryReportRequest req);

        IEnumerable<RptInventoryValuationRow> InventoryValuation(InventoryReportRequest req);

        IEnumerable<RptInventoryMovementRow> InventoryMovement(InventoryReportRequest req);

        IEnumerable<RptInventoryIncomingRow> InventoryIncoming();
    }
}
