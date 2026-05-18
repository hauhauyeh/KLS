using Microsoft.AspNetCore.Http;

namespace KLS.Models
{
    public class BankFeedUploadPreviewReq
    {
        public IFormFile? File { get; set; }
    }
}
