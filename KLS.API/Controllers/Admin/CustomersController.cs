using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [Route("api/admin/[controller]")]
    [Display(Name = "Customer Management", GroupName = "Admin")]
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
        public IActionResult GetAllCustomers()
        {
            return Ok(_customerService.GetAllCustomers());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_customerService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Customer")]
        public IActionResult CreateCustomer([FromBody] CustomerDTO customerDTO)
        {
            if (_customerService.CustomerExists(customerDTO))
                return Conflict("Customer name already exists.");

            var created = _customerService.CreateCustomer(customerDTO);

            return Ok(created);
        }


        [HttpPut]
        [DisplayName("Update Customer")]
        public IActionResult UpdateCustomer([FromBody] CustomerDTO customerDTO)
        {
            if (_customerService.CustomerExists(customerDTO))
                return Conflict("Customer name already exists.");

            var created = _customerService.UpdateCustomer(customerDTO);

            return Ok(created);
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Customer")]
        public IActionResult DeleteCustomer(int id)
        {
            _customerService.DeleteCustomer(id);

            return Ok();
        }

        #endregion
    }
}
