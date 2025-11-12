using KLS.API.Helpers;
using KLS.Models;
using KLS.Services;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace KLS.API.Controllers.Admin
{
    [AuthorizeAdmin]
    [Route("api/admin/[controller]")]
    [Display(Name = "DocumentTemplate Management", GroupName = "Admin")]
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
            return Ok(_documentTemplateService.GetAllDocumentTemplate());
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
        [DisplayName("Create DocumentTemplate ")]
        public IActionResult Create([FromBody] DocumentTemplate documentTemplate)
        {
            if (_documentTemplateService.NameExists(documentTemplate))
                return Conflict("DocumentTemplate  name already exists");

            return Ok(_documentTemplateService.CreateDocumentTemplate(documentTemplate));
        }


        [HttpPut]
        [DisplayName("Update DocumentTemplate ")]
        public IActionResult Update([FromBody] DocumentTemplate documentTemplate)
        {
            if (_documentTemplateService.NameExists(documentTemplate))
                return Conflict("DocumentTemplate name already exists");

            return Ok(_documentTemplateService.UpdateDocumentTemplate(documentTemplate));
        }


        [HttpDelete("{id}")]
        [DisplayName("Delete DocumentTemplate")]
        public IActionResult Delete(int id)
        {
            _documentTemplateService.DeleteDocumentTemplate(id);
            return Ok();
        }

        #endregion
    }
}
