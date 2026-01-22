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
    [Display(Name = "Document Template Management", GroupName = "Admin")]
    public class DocumentTemplatesController : BaseController
    {
        #region --- Member(s) ---

        private readonly IDocumentTemplateService _documentTemplateService;

        #endregion

        #region --- Constructor(s) ---

        public DocumentTemplatesController(IDocumentTemplateService documentTemplateService)
        {
            _documentTemplateService = documentTemplateService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        [DisplayName("List DocumentTemplate")]
        public IActionResult List()
        {
            return Ok(_documentTemplateService.GetList());
        }


        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var documentTemplate = _documentTemplateService.GetById(id);

            if (documentTemplate == null)
                return NotFound($"DocumentTemplate with ID {id} not found.");

            return Ok(documentTemplate);
        }


        [HttpPost]
        [DisplayName("Create Document Template")]
        public IActionResult Create([FromBody] DocumentTemplate documentTemplate)
        {
            if (_documentTemplateService.Exists(documentTemplate))
                return Conflict("DocumentTemplate  name already exists");

            return Ok(_documentTemplateService.Create(documentTemplate));
        }


        [HttpPut]
        [DisplayName("Update Document Template ")]
        public IActionResult Update([FromBody] DocumentTemplate documentTemplate)
        {
            if (_documentTemplateService.Exists(documentTemplate))
                return Conflict("DocumentTemplate name already exists");

            return Ok(_documentTemplateService.Update(documentTemplate));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete Document Template")]
        public IActionResult Delete(int id)
        {
            _documentTemplateService.Delete(id);
            return Ok();
        }

        #endregion
    }
}
