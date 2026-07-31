using KLS.API.Helpers;
using KLS.Common;
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
        private readonly IUserAccountService _userAccountService;

        #endregion

        #region --- Constructor(s) ---

        public CustomersController(ICustomerService customerService, IPayeeService payeeService, IUserAccountService userAccountService)
        {
            _customerService = customerService;
            _payeeService = payeeService;
            _userAccountService = userAccountService;
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
            _customerService.EnsureVisible(id);
            _payeeService.OpenClose(id);

            return Ok();
        }


        [HttpGet("Search")]
        public IActionResult Search([FromQuery] PayeeSearchReq searchReq)
        {
            return Ok(_customerService.Search(searchReq));
        }


        [HttpPost("GeocodeBackfill")]
        public IActionResult GeocodeBackfill([FromQuery] bool overwriteExisting = false)
        {
            return Ok(_customerService.GeocodeBackfill(overwriteExisting));
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


        [HttpPost("{payeeId}/accounts")]
        public IActionResult CreateAccount(int payeeId, [FromBody] UserAccountDto dto)
        {
            _customerService.EnsureVisible(payeeId);

            if (string.IsNullOrWhiteSpace(dto.Password))
                return BadRequest("Password is required.");

            if (_userAccountService.UsernameExists(dto.Username, 0))
                return Conflict("Username already registered.");

            if (_userAccountService.EmailExists(dto.Email, 0))
                return Conflict("Email already registered.");

            if (!string.IsNullOrWhiteSpace(dto.Phone) && _userAccountService.PhoneExists(dto.Phone, 0))
                return Conflict("Phone number already registered.");

            var account = new UserAccount
            {
                PayeeId = payeeId,
                RoleId = dto.RoleId,
                Username = dto.Username,
                Email = dto.Email,
                Phone = dto.Phone,
                PasswordHash = Utilities.Encrypt(dto.Password!),
                Inactive = dto.Inactive
            };

            var created = _userAccountService.CreateForAdmin(account);

            return Ok(new { created.UserId });
        }


        [HttpPut("{payeeId}/accounts/{userId}")]
        public IActionResult UpdateAccount(int payeeId, int userId, [FromBody] UserAccountDto dto)
        {
            _customerService.EnsureVisible(payeeId);

            var existing = _userAccountService.GetById(userId);
            if (existing == null || existing.PayeeId != payeeId)
                return NotFound("Account not found.");

            if (_userAccountService.UsernameExists(dto.Username, userId))
                return Conflict("Username already registered.");

            if (_userAccountService.EmailExists(dto.Email, userId))
                return Conflict("Email already registered.");

            if (!string.IsNullOrWhiteSpace(dto.Phone) && _userAccountService.PhoneExists(dto.Phone, userId))
                return Conflict("Phone number already registered.");

            var account = new UserAccount
            {
                UserId = userId,
                Username = dto.Username,
                Email = dto.Email,
                Phone = dto.Phone,
                Inactive = dto.Inactive,
                PasswordHash = !string.IsNullOrWhiteSpace(dto.Password) ? Utilities.Encrypt(dto.Password) : string.Empty
            };

            _userAccountService.UpdateForAdmin(account);

            return Ok();
        }


        [HttpDelete("{payeeId}/accounts/{userId}")]
        public IActionResult DeleteAccount(int payeeId, int userId)
        {
            _customerService.EnsureVisible(payeeId);

            var existing = _userAccountService.GetById(userId);
            if (existing == null || existing.PayeeId != payeeId)
                return NotFound("Account not found.");

            if (existing.RoleId == 1)
                return BadRequest("Cannot delete the owner account.");

            _userAccountService.DeleteForAdmin(userId, payeeId);

            return Ok();
        }

        #endregion
    }
}
