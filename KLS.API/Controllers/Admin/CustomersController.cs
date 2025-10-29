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
    [Display(Name = "Customer Management", GroupName = "Customer")]
    public class CustomersController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICustomerService _customerService;

        #endregion

        #region --- Constructor(s) ---

        public CustomersController(ICustomerService customerService)
        {
            _customerService = customerService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Customers")]
        public IActionResult List([FromQuery] CustomerListReq customerListReq)
        {
            return Ok(_customerService.GetAllCustomers(customerListReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_customerService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Customer")]
        public IActionResult Create([FromBody] CustomerDTO customerDTO)
        {
            if (_customerService.CustomerExists(customerDTO))
                return Conflict("Customer name already exists.");

            var created = _customerService.CreateCustomer(customerDTO);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Customer")]
        public IActionResult Update([FromBody] CustomerDTO customerDTO)
        {
            if (_customerService.CustomerExists(customerDTO))
                return Conflict("Customer name already exists.");

            var created = _customerService.UpdateCustomer(customerDTO);

            return Ok(created);
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Customer")]
        public IActionResult Delete(int id)
        {
            _customerService.DeleteCustomer(id);

            return Ok();
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] PayeeSearchReq searchReq)
        {
            return Ok(_customerService.SearchCustomer(searchReq));
        }

        #endregion
    }
}
