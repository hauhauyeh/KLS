using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Warehouse
{
    [Route("api/warehouse/[controller]")]
    public class PrintLabelsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ILabelPrintLogService _labelPrintLogService;

        #endregion

        #region --- Constructor(s) ---

        public PrintLabelsController(ILabelPrintLogService labelPrintLogService)
        {
            _labelPrintLogService = labelPrintLogService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost]
        public IActionResult PrintLabel([FromBody] PrintLabelReq labelReq)
        {
            if (string.IsNullOrEmpty(labelReq.IPAddress))
                return NotFound();

            _labelPrintLogService.Create(labelReq);
            return Ok();
        }

        #endregion
    }
}
