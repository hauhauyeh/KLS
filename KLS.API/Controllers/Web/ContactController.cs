using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Web
{
    [Route("api/web/[controller]")]
    public class ContactController : BaseController
    {
        #region --- Member(s) ---

        private readonly IContactService _contactService;

        #endregion

        #region --- Constructor(s) ---

        public ContactController(IContactService contactService)
        {
            _contactService = contactService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost]
        public IActionResult Send([FromBody] ContactMessageReq req)
        {
            _contactService.SendMessage(req);
            return Ok(new { Message = "Message sent." });
        }

        #endregion
    }
}
