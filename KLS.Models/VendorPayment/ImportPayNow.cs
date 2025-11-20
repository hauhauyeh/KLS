using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ImportPayNow
    {
        public string? PaymentMethod { get; set; }

        public int? FromAccountId { get; set; }

        public string? FilePath { get; set; }

        public IFormFile? ExcelFile { get; set; }
    }
}
