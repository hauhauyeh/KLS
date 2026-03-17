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
        public IActionResult BalanceSheet(DateOnly? endDate)
        {
            return Ok(_reportService.BalanceSheet(endDate));
        }


        [HttpGet("ProfitLoss")]
        [DisplayName("PL -> Profit Loss")]
        public IActionResult ProfitLoss([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.ProfitLoss(reportReq));
        }

        #endregion

        #region --- Sales ---

        [HttpGet("SalesDaily")]
        [DisplayName("Sales -> Sales Daily")]
        public IActionResult SalesDaily([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.SalesDaily(reportReq));
        }


        [HttpGet("SalesTax")]
        [DisplayName("Sales -> Sales Tax")]
        public IActionResult SalesTax([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.SalesTax(reportReq));
        }


        [HttpGet("Responsible")]
        [DisplayName("Sales -> Responsible")]
        public IActionResult Responsible([FromQuery] DateOnly? ShipDate)
        {
            var result = _reportService.Responsible(ShipDate);
            return Ok(result);
        }


        [HttpGet("DailySummary")]
        [DisplayName("Sales -> DailySummary")]
        public IActionResult DailySummary([FromQuery] DateOnly? ShipDate)
        {
            var result = _reportService.DailySummary(ShipDate);
            return Ok(result);
        }

        #endregion

        [HttpGet("DescDollar")]
        [DisplayName("Customer -> Descending Dollar")]
        public IActionResult DescDollar([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.DescDollar(reportReq));
        }


        [HttpGet("PaymentHistory/{PayeeId}")]
        [DisplayName("Customer -> Payment History")]
        public IActionResult PaymentHistory(int PayeeId)
        {
            return Ok(_reportService.PaymentHistory(PayeeId));
        }

        [HttpGet("Ledger")]
        [DisplayName("PL -> Ledger")]
        public IActionResult Ledger([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.Ledger(reportReq));
        }

        #region --- Customer ---

        [HttpGet("CustStmt/{PayeeId}")]
        [DisplayName("Customer -> Statement")]
        public IActionResult CustStmt(int PayeeId)
        {
            return Ok(_reportService.CustStmt(PayeeId));
        }

        [HttpGet("AccountHistory/{PayeeId}")]
        [DisplayName("Customer -> Account History")]
        public IActionResult AccountHistory(int PayeeId)
        {
            return Ok(_reportService.AccountHistory(PayeeId));
        }

        [HttpGet("Pricesheet/{PayeeId}")]
        [DisplayName("Customer -> Pricesheet")]
        public IActionResult Pricesheet(int PayeeId)
        {
            return Ok(_reportService.Pricesheet(PayeeId));
        }

        [HttpGet("OrderGuide/{PayeeId}")]
        [DisplayName("Customer -> Order Guide")]
        public IActionResult OrderGuide(int PayeeId)
        {
            return Ok(_reportService.OrderGuide(PayeeId));
        }

        [HttpGet("CustItemVolume/{PayeeId}")]
        [DisplayName("Customer -> Item Volume History")]
        public IActionResult CustItemVolume(int PayeeId)
        {
            return Ok(_reportService.CustItemVolume(PayeeId));
        }

        [HttpGet("CustSalesByItem")]
        [DisplayName("Customer -> Sales By Item")]
        public IActionResult CustSalesByItem([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.CustSalesByItem(reportReq));
        }

        [HttpGet("SalesHistory")]
        [DisplayName("Customer -> Sales History")]
        public IActionResult SalesHistory([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.SalesHistory(reportReq));
        }

        [HttpGet("CustPayment")]
        [DisplayName("Customer -> Customer Payment")]
        public IActionResult CustPayment([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.CustPayment(reportReq));
        }

        [HttpGet("CreditMemo")]
        [DisplayName("Sales -> Credit Memo")]
        public IActionResult CreditMemo([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.CreditMemo(reportReq));
        }

        [HttpGet("PmtReceipt/{CustomerPaymentId}")]
        [DisplayName("Banking -> Payment Receipt")]
        public IActionResult PmtReceipt(int CustomerPaymentId)
        {
            return Ok(_customerPaymentService.GetByIdWithInclude(CustomerPaymentId));
        }

        #endregion

        #region --- Timesheet ---

        [HttpGet("Timesheet")]
        [DisplayName("Timesheet -> Timesheet")]
        public IActionResult Timesheet([FromQuery] TimesheetReq timesheetReq)
        {
            return Ok(_timesheetService.GetWeeklyTimesheets(timesheetReq));
        }


        [HttpGet("JobSummary")]
        [DisplayName("Timesheet -> Job Summary")]
        public IActionResult JobSummary([FromQuery] ReportRequest reportReq)
        {
            return Ok(_reportService.JobSummary(reportReq));
        }

        #endregion
    }
}
