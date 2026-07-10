using Microsoft.AspNetCore.Http;

namespace KLS.Models
{
    public class ImportPayNowPreviewReq
    {
        public IFormFile? ExcelFile { get; set; }
    }
}
