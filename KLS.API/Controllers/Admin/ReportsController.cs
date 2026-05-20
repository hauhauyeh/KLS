using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Report Management", GroupName = "Report")]
    public class ReportsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IReportService _reportService;
        private readonly ICustomerPaymentService _customerPaymentService;
        private readonly ITimesheetService _timesheetService;

        #endregion

        #region --- Constructor(s) ---

        public ReportsController(IReportService reportService, ICustomerPaymentService customerPaymentService, ITimesheetService timesheetService)
        {
            _reportService = reportService;
            _customerPaymentService = customerPaymentService;
            _timesheetService = timesheetService;
        }

        #endregion

        #region --- Profit and Loss ---

        [HttpGet("BalanceSheet/{endDate}")]
        [DisplayName("PL -> Balance Sheet")]
        [PermissionKey("Report.PL.BalanceSheet")]
        public IActionResult BalanceSheet(DateOnly? endDate)
        {
            return Ok(_reportService.BalanceSheet(endDate));
        }


        [HttpGet("ProfitLoss")]
        [DisplayName("PL -> Profit Loss")]
        [PermissionKey("Report.PL.ProfitLoss")]
        public IActionResult ProfitLoss([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.ProfitLoss(reportReq));
        }

        #endregion

        #region --- Sales ---

        [HttpGet("SalesDaily")]
        [DisplayName("Sales -> Sales Daily")]
        [PermissionKey("Report.Sales.SalesDaily")]
        public IActionResult SalesDaily([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.SalesDaily(reportReq));
        }


        [HttpGet("SalesTax")]
        [DisplayName("Sales -> Sales Tax")]
        [PermissionKey("Report.Sales.SalesTax")]
        public IActionResult SalesTax([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.SalesTax(reportReq));
        }

        [HttpGet("ServiceSummary")]
        [DisplayName("Sales -> Sales by Service Rep")]
        [PermissionKey("Report.Sales.ServiceSummary")]
        public IActionResult ServiceSummary([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.ServiceSummary(reportReq));
        }

        [HttpGet("SalesCallList")]
        [DisplayName("Sales -> Sales Call List")]
        [PermissionKey("Report.Sales.SalesCallList")]
        public IActionResult SalesCallList()
        {
            return Ok(_reportService.SalesCallList());
        }

        [HttpGet("VendorPurchaseSummary")]
        [DisplayName("Purchase -> Vendor Purchase Summary")]
        [PermissionKey("Report.Purchase.VendorPurchaseSummary")]
        public IActionResult VendorPurchaseSummary([FromQuery] bool IncludeClosed = false)
        {
            return Ok(_reportService.VendorPurchaseSummary(IncludeClosed));
        }

        [HttpGet("CustomerSalesSummary")]
        [DisplayName("Sales -> Customer Sales Summary")]
        [PermissionKey("Report.Sales.CustomerSalesSummary")]
        public IActionResult CustomerSalesSummary(
            [FromQuery] bool IncludeClosed = false,
            [FromQuery] int? SalesRepId = null)
        {
            return Ok(_reportService.CustomerSalesSummary(IncludeClosed, SalesRepId));
        }

        [HttpGet("SalesSummary")]
        [DisplayName("Sales -> Sales Summary")]
        [PermissionKey("Report.Sales.SalesSummary")]
        public IActionResult SalesSummary(
            [FromQuery] string Grain = "month",
            [FromQuery] DateOnly? StartDate = null,
            [FromQuery] DateOnly? EndDate = null,
            [FromQuery] int? SalesRepId = null)
        {
            return Ok(_reportService.SalesSummary(Grain, StartDate, EndDate, SalesRepId));
        }


        [HttpGet("Responsible")]
        [DisplayName("Sales -> Responsible")]
        [PermissionKey("Report.Sales.Responsible")]
        public IActionResult Responsible([FromQuery] DateOnly? ShipDate)
        {
            var result = _reportService.Responsible(ShipDate);
            return Ok(result);
        }


        [HttpGet("DailySummary")]
        [DisplayName("Sales -> DailySummary")]
        [PermissionKey("Report.Sales.DailySummary")]
        public IActionResult DailySummary([FromQuery] DateOnly? ShipDate)
        {
            var result = _reportService.DailySummary(ShipDate);
            return Ok(result);
        }

        #endregion

        [HttpGet("DescDollar")]
        [DisplayName("Customer -> Descending Dollar")]
        [PermissionKey("Report.Customer.DescDollar")]
        public IActionResult DescDollar([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.DescDollar(reportReq));
        }


        [HttpGet("PaymentHistory/{PayeeId}")]
        [DisplayName("Customer -> Payment History")]
        [PermissionKey("Report.Customer.PaymentHistory")]
        public IActionResult PaymentHistory(int PayeeId)
        {
            return Ok(_reportService.PaymentHistory(PayeeId));
        }

        [HttpGet("Ledger")]
        [DisplayName("PL -> Ledger")]
        [PermissionKey("Report.PL.Ledger")]
        public IActionResult Ledger([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.Ledger(reportReq));
        }


        [HttpGet("LedgerByPayee")]
        [DisplayName("PL -> Ledger By Payee")]
        [PermissionKey("Report.PL.LedgerByPayee")]
        public IActionResult LedgerByPayee([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.LedgerByPayee(reportReq));
        }


        [HttpGet("BankRecon/{BankReconId}")]
        [DisplayName("Banking -> Bank Reconciliation")]
        [PermissionKey("Report.Banking.BankRecon")]
        public IActionResult BankRecon(int BankReconId)
        {
            return Ok(_reportService.BankRecon(BankReconId));
        }

        #region --- Customer ---

        [HttpGet("CustStmt/{PayeeId}")]
        [DisplayName("Customer -> Statement")]
        [PermissionKey("Report.Customer.Statement")]
        public IActionResult CustStmt(int PayeeId)
        {
            return Ok(_reportService.CustStmt(PayeeId));
        }

        [HttpGet("AccountHistory/{PayeeId}")]
        [DisplayName("Customer -> Account History")]
        [PermissionKey("Report.Customer.AccountHistory")]
        public IActionResult AccountHistory(int PayeeId)
        {
            return Ok(_reportService.AccountHistory(PayeeId));
        }

        [HttpGet("Pricesheet/{PayeeId}")]
        [DisplayName("Customer -> Pricesheet")]
        [PermissionKey("Report.Customer.Pricesheet")]
        public IActionResult Pricesheet(int PayeeId)
        {
            return Ok(_reportService.Pricesheet(PayeeId));
        }

        [HttpGet("OrderGuide/{PayeeId}")]
        [DisplayName("Customer -> Order Guide")]
        [PermissionKey("Report.Customer.OrderGuide")]
        public IActionResult OrderGuide(int PayeeId)
        {
            return Ok(_reportService.OrderGuide(PayeeId));
        }

        [HttpGet("CustItemVolume/{PayeeId}")]
        [DisplayName("Customer -> Item Volume History")]
        [PermissionKey("Report.Customer.ItemVolume")]
        public IActionResult CustItemVolume(int PayeeId)
        {
            return Ok(_reportService.CustItemVolume(PayeeId));
        }

        [HttpGet("CustSalesByItem")]
        [DisplayName("Customer -> Sales By Item")]
        [PermissionKey("Report.Customer.SalesByItem")]
        public IActionResult CustSalesByItem([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.CustSalesByItem(reportReq));
        }

        [HttpGet("SalesHistory")]
        [DisplayName("Customer -> Sales History")]
        [PermissionKey("Report.Customer.SalesHistory")]
        public IActionResult SalesHistory([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.SalesHistory(reportReq));
        }

        [HttpGet("PurchaseHistory")]
        [DisplayName("Vendor -> Purchase History")]
        [PermissionKey("Report.Vendor.PurchaseHistory")]
        public IActionResult PurchaseHistory([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.PurchaseHistory(reportReq));
        }

        [HttpGet("ItemCustomerAnalysis")]
        [DisplayName("Item -> Item Customer Analysis")]
        [PermissionKey("Report.Item.ItemCustomerAnalysis")]
        public IActionResult ItemCustomerAnalysis([FromQuery] ItemCustomerAnalysisRequest reportReq)
        {
            return Ok(_reportService.ItemCustomerAnalysis(reportReq));
        }

        [HttpGet("CustPayment")]
        [DisplayName("Customer -> Customer Payment")]
        [PermissionKey("Report.Customer.CustPayment")]
        public IActionResult CustPayment([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.CustPayment(reportReq));
        }

        [HttpGet("CreditMemo")]
        [DisplayName("Sales -> Credit Memo")]
        [PermissionKey("Report.Sales.CreditMemo")]
        public IActionResult CreditMemo([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.CreditMemo(reportReq));
        }

        [HttpGet("PmtReceipt/{CustomerPaymentId}")]
        [DisplayName("Banking -> Payment Receipt")]
        [PermissionKey("Report.Banking.PmtReceipt")]
        public IActionResult PmtReceipt(int CustomerPaymentId)
        {
            return Ok(_customerPaymentService.GetByIdWithInclude(CustomerPaymentId));
        }

        #endregion

        #region --- AP ---

        [HttpGet("APCheck")]
        [DisplayName("AP -> AP Check")]
        [PermissionKey("Report.AP.APCheck")]
        public IActionResult APCheck([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.APCheck(reportReq));
        }


        [HttpGet("CheckToBePrinted/{PmtMethod?}")]
        [DisplayName("AP -> Check To Be Printed")]
        [PermissionKey("Report.AP.CheckToBePrinted")]
        public IActionResult CheckToBePrinted(string? PmtMethod)
        {
            return Ok(_reportService.CheckToBePrinted(PmtMethod));
        }


        [HttpGet("APInvoice")]
        [DisplayName("AP -> AP From Invoice")]
        [PermissionKey("Report.AP.APInvoice")]
        public IActionResult APInvoice([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.APInvoice(reportReq));
        }

        #endregion

        #region --- Timesheet ---

        [HttpGet("Timesheet")]
        [DisplayName("Timesheet -> Timesheet")]
        [PermissionKey("Report.Timesheet.Timesheet")]
        public IActionResult Timesheet([FromQuery] TimesheetReq timesheetReq)
        {
            return Ok(_timesheetService.GetWeeklyTimesheets(timesheetReq));
        }


        [HttpGet("JobSummary")]
        [DisplayName("Timesheet -> Job Summary")]
        [PermissionKey("Report.Timesheet.JobSummary")]
        public IActionResult JobSummary([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.JobSummary(reportReq));
        }

        #endregion

        #region --- Payroll ---

        [HttpGet("Payroll")]
        [DisplayName("Payroll -> Payroll")]
        [PermissionKey("Report.Payroll.Payroll")]
        public IActionResult Payroll([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.Payroll(reportReq));
        }


        [HttpGet("EmpLoanLedger")]
        [DisplayName("Payroll -> Employee Loan Ledger")]
        [PermissionKey("Report.Payroll.EmpLoanLedger")]
        public IActionResult EmpLoanLedger([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.EmpLoanLedger(reportReq));
        }

        #endregion

        #region --- Sales By Item / Detail ---

        [HttpGet("SalesByItem")]
        [DisplayName("Sales -> Sales By Item")]
        [PermissionKey("Report.Sales.SalesByItem")]
        public IActionResult SalesByItem([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.CustSalesByItem(reportReq));
        }


        [HttpGet("SalesDetail")]
        [DisplayName("Sales -> Sales Detail")]
        [PermissionKey("Report.Sales.SalesDetail")]
        public IActionResult SalesDetail([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.SalesDetail(reportReq));
        }

        #endregion

        #region --- Sales Daily/Yearly ---

        [HttpGet("SalesDaily2")]
        [DisplayName("Sales -> Sales Daily 2")]
        [PermissionKey("Report.Sales.SalesDaily2")]
        public IActionResult SalesDaily2([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.SalesDaily2(reportReq));
        }

        [HttpGet("SalesByInvoice")]
        [DisplayName("Sales -> Sales By Invoice")]
        [PermissionKey("Report.Sales.SalesByInvoice")]
        public IActionResult SalesByInvoice([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.SalesByInvoice(reportReq));
        }


        [HttpGet("SalesYearly")]
        [DisplayName("Sales -> Sales Yearly")]
        [PermissionKey("Report.Sales.SalesYearly")]
        public IActionResult SalesYearly()
        {
            return Ok(_reportService.SalesYearly());
        }

        #endregion

        #region --- Sales Commission ---

        [HttpGet("SalesCommission")]
        [DisplayName("Sales -> Sales Commission")]
        [PermissionKey("Report.Sales.SalesCommission")]
        public IActionResult SalesCommission([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.SalesCommission(reportReq));
        }


        [HttpGet("SalesCommission2")]
        [DisplayName("Sales -> Sales Commission 2")]
        [PermissionKey("Report.Sales.SalesCommission2")]
        public IActionResult SalesCommission2([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.SalesCommission2(reportReq));
        }

        #endregion

        #region --- AR ---

        [HttpGet("ARInvoice")]
        [DisplayName("AR -> AR From Invoice")]
        [PermissionKey("Report.AR.ARInvoice")]
        public IActionResult ARInvoice([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.ARInvoice(reportReq));
        }


        [HttpGet("ARMonth")]
        [DisplayName("AR -> AR Month")]
        [PermissionKey("Report.AR.ARMonth")]
        public IActionResult ARMonth([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.ARMonth(reportReq));
        }

        #endregion

        #region --- Inventory ---

        [HttpGet("InventoryStatus")]
        [DisplayName("Inventory -> Inventory Status")]
        [PermissionKey("Report.Inventory.InventoryStatus")]
        public IActionResult InventoryStatus([FromQuery] InventoryReportRequest req)
        {
            return Ok(_reportService.InventoryStatus(req));
        }


        [HttpGet("Reorder")]
        [DisplayName("Inventory -> Reorder")]
        [PermissionKey("Report.Inventory.Reorder")]
        public IActionResult Reorder([FromQuery] InventoryReportRequest req)
        {
            return Ok(_reportService.Reorder(req));
        }


        [HttpGet("InventoryValuation")]
        [DisplayName("Inventory -> Inventory Valuation")]
        [PermissionKey("Report.Inventory.InventoryValuation")]
        public IActionResult InventoryValuation([FromQuery] InventoryReportRequest req)
        {
            return Ok(_reportService.InventoryValuation(req));
        }


        [HttpGet("InventoryMovement")]
        [DisplayName("Inventory -> Inventory Movement")]
        [PermissionKey("Report.Inventory.InventoryMovement")]
        public IActionResult InventoryMovement([FromQuery] InventoryReportRequest req)
        {
            return Ok(_reportService.InventoryMovement(req));
        }


        [HttpGet("InventoryIncoming")]
        [DisplayName("Inventory -> Incoming Purchases")]
        [PermissionKey("Report.Inventory.InventoryIncoming")]
        public IActionResult InventoryIncoming()
        {
            return Ok(_reportService.InventoryIncoming());
        }


        [HttpGet("WorksheetPattern")]
        [DisplayName("Inventory -> Worksheet Pattern")]
        [PermissionKey("Report.Inventory.InventoryStatus")]
        public IActionResult WorksheetPattern([FromQuery] WorksheetPatternReportRequest req)
        {
            return Ok(_reportService.WorksheetPattern(req));
        }

        #endregion
    }
}
