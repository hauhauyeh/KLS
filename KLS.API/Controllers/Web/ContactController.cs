using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Web
{
    [Route("api/web/[controller]")]
    [Display(Name = "Contact", GroupName = "Web")]
    public class ContactController : BaseController
    {
        private readonly IContactService _contactService;

        public ContactController(IContactService contactService)
        {
            _contactService = contactService;
        }

        [HttpPost]
        public IActionResult Send([FromBody] ContactMessageReq req)
        {
            _contactService.SendMessage(req);
            return Ok(new { Message = "Message sent." });
        }
    }
}
