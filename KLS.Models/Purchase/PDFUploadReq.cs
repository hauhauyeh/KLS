using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PDFUploadReq
    {
        public int PurchaseNumber { get; set; }

        public IFormFile? PDFFile { get; set; }
    }
}
