using KLS.API.Helpers;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Bank Reconciliation Management", GroupName = "Admin")]
    public class BankReconsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IBankReconService _bankReconService;

        #endregion

        #region --- Constructor(s) ---

        public BankReconsController(IBankReconService bankReconService)
        {
            _bankReconService = bankReconService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List BankRecon")]
        public IActionResult List()
        {
            return Ok(_bankReconService.GetAllBankRecon());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_bankReconService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create BankRecon")]
        public IActionResult Create([FromBody] BankRecon bankRecon)
        {
            if (_bankReconService.ExistsBankRecon(bankRecon))
                return Conflict("You can only Reconciliation further statement date.");

            return Ok(_bankReconService.CreateBankRecon(bankRecon));
        }


        [HttpPut]
        [DisplayName("Update BankRecon")]
        public IActionResult Update([FromBody] BankRecon bankRecon)
        {
            if (_bankReconService.ExistsBankRecon(bankRecon))
                return Conflict("You can only Reconciliation further statement date.");

            return Ok(_bankReconService.UpdateBankRecon(bankRecon));
        }


        [HttpPost("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] BankRecon bankRecon)
        {
            _bankReconService.UpdateNotes(bankRecon);

            return Ok();
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete BankRecon")]
        public IActionResult Delete(int id)
        {
            //if (_truckService.TermUsed(id))
            //    return Conflict("You can't delete. it is assigned to payee.");

            _bankReconService.DeleteBankRecon(id);

            return Ok();
        }

        #endregion
    }
}
