using KLS.Contract.Services;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Service
{
    [Route("api/service/[controller]")]
    public class PrintLogsController : BaseController
    {
        #region --- Member(s) ---

        private readonly IPrintLogService _printLogService;

        #endregion

        #region --- Constructor(s) ---

        public PrintLogsController(IPrintLogService printLogService)
        {
            _printLogService = printLogService;
        }

        #endregion

        #region --- Method(s) ---

        [HttpGet]
        public IActionResult GetLogs()
        {
            return Ok(_printLogService.GetLogs());
        }


        [HttpGet("{logId}")]
        public IActionResult GetDocPdf(int logId)
        {
            var filePath = _printLogService.GetDocPDF(logId);

            var fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read);
            return File(fileStream, "application/pdf");
        }


        [HttpPost("{logId}")]
        public IActionResult Update(int logId)
        {
            _printLogService.Update(logId);
            return Ok();
        }

        #endregion
    }
}
