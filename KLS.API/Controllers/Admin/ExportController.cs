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
    [Display(Name = "Export Data Management", GroupName = "Admin")]
    public class ExportController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICustomerService _customerService;
        private readonly IVendorService _vendorService;
        private readonly ISalesService _salesService;

        #endregion

        #region --- Constructor(s) ---

        public ExportController(ICustomerService customerService, IVendorService vendorService, ISalesService salesService)
        {
            _customerService = customerService;
            _vendorService = vendorService;
            _salesService = salesService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("Customers")]
        [DisplayName("Export Customers")]
        public IActionResult Customers()
        {
            var bytes = _customerService.Export();

            return File(
                bytes,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"Customer_{DateTime.Now:yyyyMMddHHmmss}.xlsx");
        }


        [HttpGet("Vendors")]
        [DisplayName("Export Vendors")]
        public IActionResult Vendors()
        {
            var bytes = _vendorService.Export();

            return File(
               bytes,
               "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
               $"Vendor_{DateTime.Now:yyyyMMddHHmmss}.xlsx");
        }


        [HttpGet("Orders")]
        [DisplayName("Export Orders")]
        public IActionResult Order([FromQuery] SalesExportReq exportReq)
        {
            var bytes = _salesService.Export(exportReq);

            return File(
                bytes,
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                $"Order_{DateTime.Now:yyyyMMddHHmmss}.xlsx");
        }

        #endregion
    }

}
