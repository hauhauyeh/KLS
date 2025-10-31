using KLS.API.Helpers;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "ItemQuote Management", GroupName = "Admin")]
    public class ItemQuotesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IItemQuoteService _itemQuoteService;

        #endregion

        #region --- Constructor(s) ---

        public ItemQuotesController(IItemQuoteService itemQuoteService)
        {
            _itemQuoteService = itemQuoteService;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}
