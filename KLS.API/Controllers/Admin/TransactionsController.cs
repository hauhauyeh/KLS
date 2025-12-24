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
    [Display(Name = "Transaction Management", GroupName = "Accounting")]
    public class TransactionsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ITransactionService _transactionService;
        private readonly ISourceDocTypeService _docTypeService;

        #endregion

        #region --- Constructor(s) ---

        public TransactionsController(ITransactionService transactionService, ISourceDocTypeService docTypeService)
        {
            _transactionService = transactionService;
            _docTypeService = docTypeService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List Transaction")]
        public IActionResult List([FromQuery] TxReq txReq)
        {
            return Ok(_transactionService.GetPagedList(txReq));
        }


        [HttpGet("GetTxDetail/{TxId}")]
        public IActionResult GetTxDetail(int TxId)
        {
            return Ok(_transactionService.GetTxDetail(TxId));
        }


        [HttpGet("GetDocTypes")]
        public IActionResult GetDocTypes()
        {
            return Ok(_docTypeService.GetList());
        }

        #endregion
    }
}
