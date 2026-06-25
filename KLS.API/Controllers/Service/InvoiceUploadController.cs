using KLS.Models;
using Microsoft.AspNetCore.Mvc;

namespace KLS.API.Controllers.Service
{
    [Route("api/service/[controller]")]
    public class InvoiceUploadController : BaseController
    {
        #region --- Member(s) ---

        private readonly IWebHostEnvironment _env;
        private readonly ILogger<InvoiceUploadController> _logger;

        #endregion

        #region --- Constructor(s) ---

        public InvoiceUploadController(IWebHostEnvironment env, ILogger<InvoiceUploadController> logger)
        {
            _env = env;
            _logger = logger;
        }

        #endregion

        #region --- Method(s) ---

        [HttpPost]
        [RequestSizeLimit(100 * 1024 * 1024)] // 100 MB max
        public async Task<IActionResult> Upload([FromForm] InvoiceUploadRequest request)
        {
            if (request.File == null || request.File.Length == 0)
                return BadRequest(new { error = "No file provided" });

            if (!request.File.FileName.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase))
                return BadRequest(new { error = "Only PDF files are accepted" });

            if (string.IsNullOrWhiteSpace(request.SalesNumber))
                return BadRequest(new { error = "SalesNumber is required" });

            var salesFolder = Path.Combine(_env.WebRootPath, "InvoicePdf");
            Directory.CreateDirectory(salesFolder);

            var fileName = request.SalesNumber + ".pdf";
            var filePath = Path.Combine(salesFolder, fileName);

            await using var stream = new FileStream(filePath, FileMode.Create);
            await request.File.CopyToAsync(stream);

            _logger.LogInformation(
                "Invoice uploaded: SalesNumber={SalesNumber}, File={FileName}, Size={Size} bytes, OriginalFile={OriginalFile}",
                request.SalesNumber, fileName, request.File.Length, request.OriginalFileName);

            return Ok(new
            {
                message = "Invoice uploaded successfully",
                salesNumber = request.SalesNumber,
                fileName,
                size = request.File.Length
            });
        }

        #endregion
    }
}
