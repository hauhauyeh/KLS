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
    [Display(Name = "Liability Management", GroupName = "Vendor")]
    public class LiabilitiesController : BaseController
    {
        #region --- Member(s) ---

        private readonly ILiabilityService _liabilityService;
        private readonly IVendorPaymentService _vendorPaymentService;

        #endregion

        #region --- Constructor(s) ---

        public LiabilitiesController(ILiabilityService liabilityService, IVendorPaymentService vendorPaymentService)
        {
            _liabilityService = liabilityService;
            _vendorPaymentService = vendorPaymentService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet("Loan")]
        [DisplayName("Loan Manager")]
        [PermissionKey("Vendor.Liability.LoanList")]
        public IActionResult LoanList([FromQuery] PagingRequest request)
        {
            request.Filterby = "Loan";

            return Ok(_liabilityService.GetList(request));
        }


        [HttpGet("Tax")]
        [DisplayName("Tax Manager")]
        [PermissionKey("Vendor.Liability.TaxList")]
        public IActionResult TaxList([FromQuery] PagingRequest request)
        {
            request.Filterby = "Tax";

            return Ok(_liabilityService.GetList(request));
        }


        [HttpGet("CC")]
        [DisplayName("CC Manager")]
        [PermissionKey("Vendor.Liability.CCList")]
        public IActionResult CCList([FromQuery] PagingRequest request)
        {
            request.Filterby = "CC";

            return Ok(_liabilityService.GetList(request));
        }


        [HttpGet("{payeeId}")]
        public IActionResult GetById(int payeeId)
        {
            return Ok(_liabilityService.GetById(payeeId));
        }


        [HttpPost]
        [DisplayName("Create Liability")]
        [PermissionKey("Vendor.Liability.Create")]
        public IActionResult Create([FromBody] LiabilityDto dto)
        {
            if (_liabilityService.NameExists(dto))
                return Conflict("Liability name already exists.");

            return Ok(_liabilityService.Create(dto));
        }


        [HttpPut]
        [DisplayName("Update Liability")]
        [PermissionKey("Vendor.Liability.Update")]
        public IActionResult Update([FromBody] LiabilityDto dto)
        {
            if (_liabilityService.NameExists(dto))
                return Conflict("Liability name already exists.");

            return Ok(_liabilityService.Update(dto));
        }


        [HttpDelete("{payeeId}")]
        [DisplayName("Delete Liability")]
        [PermissionKey("Vendor.Liability.Delete")]
        public IActionResult Delete(int payeeId)
        {
            _liabilityService.Delete(payeeId);
            return Ok();
        }


        [HttpDelete("DeletePayment/{paymentId}")]
        [DisplayName("Delete Payment")]
        [PermissionKey("Vendor.Liability.DeletePayment")]
        public IActionResult DeletePayment(int paymentId)
        {
            _vendorPaymentService.Delete(paymentId);
            return Ok();
        }


        [HttpGet("Tx")]
        [DisplayName("Tx List")]
        [PermissionKey("Vendor.Liability.TxList")]
        public IActionResult TxList([FromQuery] LiabilityTxListReq request)
        {
            return Ok(_liabilityService.GetTxPagedList(request));
        }


        [HttpPost("SaveLoanPayment")]
        [DisplayName("Save Loan Payment")]
        [PermissionKey("Vendor.Liability.SaveLoanPayment")]
        public IActionResult SaveLoanPayment([FromBody] LiabilityPaymentReq paymentReq)
        {
            return Ok(_liabilityService.SaveLoanPayment(paymentReq));
        }


        [HttpPost("SaveCCPayment")]
        [DisplayName("Save CC Payment")]
        [PermissionKey("Vendor.Liability.SaveCCPayment")]
        public IActionResult SaveCCPayment([FromBody] LiabilityPaymentReq paymentReq)
        {
            return Ok(_liabilityService.SaveCCPayment(paymentReq));
        }


        [HttpPost("ImportTaxPayment")]
        [DisplayName("Import Tax Payment")]
        [PermissionKey("Vendor.Liability.ImportTaxPayment")]
        public IActionResult ImportTaxPayment([FromForm] ImportTaxReq importTaxReq)
        {
            return Ok(_liabilityService.ImportTax(importTaxReq));
        }

        #endregion
    }
}
