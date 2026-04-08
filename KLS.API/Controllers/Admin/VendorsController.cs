using KLS.API.Helpers;
using KLS.Contract.Services;
using KLS.Models;
using KLS.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Vendor Management", GroupName = "Vendor")]
    public class VendorsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IVendorService _vendorService;
        private readonly IPayeeService _payeeService;

        #endregion

        #region --- Constructor(s) ---

        public VendorsController(IVendorService vendorService, IPayeeService payeeService)
        {
            _vendorService = vendorService;
            _payeeService = payeeService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Vendors")]
        [PermissionKey("Vendor.Vendor.List")]
        public IActionResult List([FromQuery] VendorListReq vendorReq)
        {
            return Ok(_vendorService.GetPagedList(vendorReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_vendorService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Vendor")]
        [PermissionKey("Vendor.Vendor.Create")]
        public IActionResult Create([FromBody] VendorDTO vendorDTO)
        {
            if (_vendorService.VendorExists(vendorDTO))
                return Conflict("Vendor name already exists.");

            var created = _vendorService.Create(vendorDTO);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Vendor")]
        [PermissionKey("Vendor.Vendor.Update")]
        public IActionResult Update([FromBody] VendorDTO vendorDTO)
        {
            if (_vendorService.VendorExists(vendorDTO))
                return Conflict("Vendor name already exists.");

            var created = _vendorService.Update(vendorDTO);

            return Ok(created);
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Vendor")]
        [PermissionKey("Vendor.Vendor.Delete")]
        public IActionResult Delete(int id)
        {
            _vendorService.Delete(id);

            return Ok();
        }


        [HttpPut("OpenClose/{id}")]
        [DisplayName("Open/Close Vendor")]
        [PermissionKey("Vendor.Vendor.OpenClose")]
        public IActionResult OpenClose(int id)
        {
            _payeeService.OpenClose(id);

            return Ok();
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] PayeeSearchReq searchReq)
        {
            return Ok(_vendorService.Search(searchReq));
        }


        [HttpGet("ActiveVendors")]
        public IActionResult ActiveVendors()
        {
            return Ok(_vendorService.GetActive());
        }


        [HttpGet("ShippingCarriers")]
        public IActionResult ShippingCarriers()
        {
            return Ok(_vendorService.ShippingCarriers());
        }

        #endregion
    }
}
