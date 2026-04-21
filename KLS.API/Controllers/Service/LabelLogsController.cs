using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Service
{
    [Route("api/service/[controller]")]
    public class LabelLogsController : BaseController
    {
        #region --- Member(s) ---

        private readonly ILabelPrintLogService _labelPrintLogService;

        #endregion

        #region --- Constructor(s) ---

        public LabelLogsController(ILabelPrintLogService labelPrintLogService)
        {
            _labelPrintLogService = labelPrintLogService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult GetLogs()
        {
            return Ok(_labelPrintLogService.GetLogs());
        }


        [HttpPost("{logId}")]
        public IActionResult Update(int logId)
        {
            var result = _labelPrintLogService.Update(logId);
            if (result == null) return NotFound();
            return Ok(result);
        }

        #endregion
    }
}
