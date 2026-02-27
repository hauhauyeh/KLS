using KLS.API.Helpers;
using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "Rest365 Management", GroupName = "")]
    public class Rest365Controller : BaseController
    {
        #region --- Member(s) ---

        private readonly IRest365Service _rest365Service;

        #endregion

        #region --- Constructor(s) ---

        public Rest365Controller(IRest365Service rest365Service)
        {
            _rest365Service = rest365Service;
        }

        #endregion

        #region --- Method(s) ---



        #endregion
    }
}