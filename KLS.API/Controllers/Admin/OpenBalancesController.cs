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
    [Display(Name = "Opening Balance", GroupName = "Accounting")]
    public class OpenBalancesController : BaseController
    {
        #region --- Member(s) ---

        private const string ExcelContentType =
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

        private readonly IOpenBalanceService _openBalanceService;

        #endregion

        #region --- Constructor(s) ---

        public OpenBalancesController(IOpenBalanceService openBalanceService)
        {
            _openBalanceService = openBalanceService;
        }

        #endregion

        #region --- Method(s) ---

        /// <summary>The five cards plus the reconciliation banner. This is the screen.</summary>
        [HttpGet("Status")]
        [DisplayName("Opening Balance")]
        [PermissionKey("Accounting.OpeningBalance.List")]
        public IActionResult Status()
        {
            return Ok(_openBalanceService.GetStatus());
        }

        /// <summary>
        /// One section's current rows as a workbook. Populated, not a blank
        /// template: correcting existing rows is the normal workflow and nobody
        /// retypes 1,858 inventory lines.
        /// </summary>
        [HttpGet("Download/{section}")]
        [DisplayName("Download Opening Balance")]
        [PermissionKey("Accounting.OpeningBalance.List")]
        public IActionResult Download(OpenBalanceSection section)
        {
            var file = _openBalanceService.Download(section);

            return File(file.Content, ExcelContentType, file.FileName);
        }

        /// <summary>All five sections in one book, for the audit file. Export only.</summary>
        [HttpGet("Export")]
        [DisplayName("Export Opening Balance")]
        [PermissionKey("Accounting.OpeningBalance.List")]
        public IActionResult Export()
        {
            var file = _openBalanceService.Export();

            return File(file.Content, ExcelContentType, file.FileName);
        }

        /// <summary>Step 1. Parse and check the upload. Writes nothing.</summary>
        [HttpPost("ImportPreview")]
        [DisplayName("Import Opening Balance")]
        [PermissionKey("Accounting.OpeningBalance.Import")]
        public IActionResult ImportPreview([FromForm] OpenBalancePreviewReq req)
        {
            return Ok(_openBalanceService.Preview(req));
        }

        /// <summary>
        /// Step 2. Save the rows and post the journal, in one transaction.
        /// Returns the refreshed status so one round trip both acts and
        /// repaints the screen.
        /// </summary>
        [HttpPost("Import")]
        [DisplayName("Import Opening Balance")]
        [PermissionKey("Accounting.OpeningBalance.Import")]
        public IActionResult Import([FromBody] OpenBalanceCommitReq req)
        {
            return Ok(_openBalanceService.Import(req));
        }

        /// <summary>Remove one section's journal. The saved rows are kept.</summary>
        [HttpPost("Unpost")]
        [DisplayName("Unpost Opening Balance")]
        [PermissionKey("Accounting.OpeningBalance.Unpost")]
        public IActionResult Unpost([FromBody] OpenBalanceSectionReq req)
        {
            return Ok(_openBalanceService.Unpost(req));
        }

        #endregion
    }
}
