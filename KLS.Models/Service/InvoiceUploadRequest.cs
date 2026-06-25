using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class InvoiceUploadRequest
    {
        public IFormFile File { get; set; } = null!;
        public string SalesNumber { get; set; } = "";
        public string OriginalFileName { get; set; } = "";
        public string SplitDate { get; set; } = "";
    }
}
