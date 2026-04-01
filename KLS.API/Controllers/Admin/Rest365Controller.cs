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
    [Display(Name = "Rest365 Management", GroupName = "Admin")]
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

        [HttpGet]
        [DisplayName("List Rest365")]
        public IActionResult List()
        {
            return Ok(_rest365Service.GetList());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var rest365 = _rest365Service.GetById(id);

            if (rest365 == null)
                return NotFound($"Rest365 with ID {id} not found.");

            return Ok(rest365);
        }


        [HttpPost]
        [DisplayName("Create Rest365")]
        public IActionResult Create([FromBody] Rest365 rest365)
        {
            if (_rest365Service.NameExists(rest365))
                return Conflict("CustomerName name already exists");

            return Ok(_rest365Service.Create(rest365));
        }


        [HttpPut]
        [DisplayName("Update Rest365")]
        public IActionResult Update([FromBody] Rest365 rest365)
        {
            if (_rest365Service.NameExists(rest365))
                return Conflict("CustomerName name already exists");

            return Ok(_rest365Service.Update(rest365));
        }


        [HttpDelete("{id}")]
        [DisplayName("Inactive")]
        public IActionResult Inactive(int id)
        {
            _rest365Service.Inactive(id);
            return Ok();
        }

        #endregion
    }
}