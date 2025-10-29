using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
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

        #endregion

        #region --- Constructor(s) ---

        public VendorsController(IVendorService vendorService)
        {
            _vendorService = vendorService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Vendors")]
        public IActionResult List([FromQuery] VendorListReq vendorReq)
        {
            return Ok(_vendorService.GetAllVendors(vendorReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_vendorService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Vendor")]
        public IActionResult Create([FromBody] VendorDTO vendorDTO)
        {
            if (_vendorService.VendorExists(vendorDTO))
                return Conflict("Vendor name already exists.");

            var created = _vendorService.CreateVendor(vendorDTO);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Vendor")]
        public IActionResult Update([FromBody] VendorDTO vendorDTO)
        {
            if (_vendorService.VendorExists(vendorDTO))
                return Conflict("Vendor name already exists.");

            var created = _vendorService.UpdateVendor(vendorDTO);

            return Ok(created);
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Vendor")]
        public IActionResult Delete(int id)
        {
            _vendorService.DeleteVendor(id);

            return Ok();
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] PayeeSearchReq searchReq)
        {
            return Ok(_vendorService.SearchVendor(searchReq));
        }

        #endregion
    }
}
