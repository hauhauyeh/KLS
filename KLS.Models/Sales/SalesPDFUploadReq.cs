using Microsoft.AspNetCore.Http;

namespace KLS.Models
{
    public class SalesPDFUploadReq
    {
        public int SalesId { get; set; }

        public IFormFile? PDFFile { get; set; }
    }
}
