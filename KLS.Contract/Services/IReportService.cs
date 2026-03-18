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

        RptARInvoice ARInvoice(ReportRequest reportReq);

        RptARMonth ARMonth(ReportRequest reportReq);
    }
}
