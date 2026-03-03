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

        #endregion

        #region --- Constructor(s) ---

        public ReportsController(IReportService reportService)
        {
            _reportService = reportService;
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
    }
}
