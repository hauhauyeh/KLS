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
    [Display(Name = "Bank Reconciliation Management", GroupName = "Accounting")]
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
        [DisplayName("List Reconciliations")]
        public IActionResult List()
        {
            return Ok(_bankReconService.GetList());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            return Ok(_bankReconService.GetById(id));
        }


        [HttpPost]
        [DisplayName("Create Reconciliation")]
        public IActionResult Create([FromBody] BankRecon bankRecon)
        {
            if (_bankReconService.Exists(bankRecon))
                return Conflict("You can only Reconciliation further statement date.");

            return Ok(_bankReconService.Create(bankRecon));
        }


        [HttpPut]
        [DisplayName("Update Reconciliation")]
        public IActionResult Update([FromBody] BankRecon bankRecon)
        {
            if (_bankReconService.Exists(bankRecon))
                return Conflict("You can only Reconciliation further statement date.");

            return Ok(_bankReconService.Update(bankRecon));
        }


        [HttpPost("UpdateNotes")]
        public IActionResult UpdateNotes([FromBody] BankRecon bankRecon)
        {
            _bankReconService.UpdateNotes(bankRecon);

            return Ok();
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Reconciliation")]
        public IActionResult Delete(int id)
        {
            _bankReconService.Delete(id);

            return Ok();
        }


        [HttpGet("GetBalance/{reconId}")]
        public IActionResult GetBalance(int reconId)
        {
            return Ok(_bankReconService.GetBalance(reconId));
        }


        [HttpGet("GetTx/{reconId}")]
        public IActionResult GetTx(int reconId)
        {
            return Ok(_bankReconService.GetTx(reconId));
        }


        [HttpPost("UpdateBankDate")]
        public IActionResult UpdateBankDate([FromBody] BankTx bankTx)
        {
            _bankReconService.UpdateBankDate(bankTx);

            return Ok();
        }

        #endregion
    }
}
