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
    [Display(Name = "Customer Management", GroupName = "Customer")]
    public class CustomersController : BaseController
    {
        #region --- Member(s) ---

        private readonly ICustomerService _customerService;
        private readonly IPayeeService _payeeService;

        #endregion

        #region --- Constructor(s) ---

        public CustomersController(ICustomerService customerService, IPayeeService payeeService)
        {
            _customerService = customerService;
            _payeeService = payeeService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Customers")]
        [PermissionKey("Customer.Customer.List")]
        public IActionResult List([FromQuery] CustomerListReq customerListReq)
        {
            return Ok(_customerService.GetPagedList(customerListReq));
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_customerService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Customer")]
        [PermissionKey("Customer.Customer.Create")]
        public IActionResult Create([FromBody] CustomerDto customerDto)
        {
            if (_customerService.NameExists(customerDto.PayeeName, customerDto.PayeeId))
                return Conflict("Customer name already exists.");

            return Ok(_customerService.Create(customerDto));
        }


        [HttpPut]
        [DisplayName("Update Customer")]
        [PermissionKey("Customer.Customer.Update")]
        public IActionResult Update([FromBody] CustomerDto customerDto)
        {
            if (_customerService.NameExists(customerDto.PayeeName, customerDto.PayeeId))
                return Conflict("Customer name already exists.");

            return Ok(_customerService.Update(customerDto));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Customer")]
        [PermissionKey("Customer.Customer.Delete")]
        public IActionResult Delete(int id)
        {
            _customerService.Delete(id);

            return Ok();
        }


        [HttpPut("OpenClose/{id}")]
        [DisplayName("Open/Close Customer")]
        [PermissionKey("Customer.Customer.OpenClose")]
        public IActionResult OpenClose(int id)
        {
            _payeeService.OpenClose(id);

            return Ok();
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] PayeeSearchReq searchReq)
        {
            return Ok(_customerService.Search(searchReq));
        }


        [HttpPost("EmailPricesheet/{payeeId}")]
        [DisplayName("Email Pricesheet")]
        [PermissionKey("Customer.Customer.EmailPricesheet")]
        public IActionResult EmailPricesheet(int payeeId)
        {
            _customerService.EmailPricesheet(payeeId);
            return Ok();
        }


        [HttpPost("EmailStatement/{payeeId}")]
        [DisplayName("Email Statement")]
        [PermissionKey("Customer.Customer.EmailStatement")]
        public IActionResult EmailStatement(int payeeId)
        {
            _customerService.EmailStatement(payeeId);
            return Ok();
        }

        #endregion
    }
}
