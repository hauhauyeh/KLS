using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class VendorSearchDTO
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? AccountCode1 { get; set; }

        public string? AccountCode2 { get; set; }

        public string? AccountCode3 { get; set; }

        public string? AccountCode4 { get; set; }

        public string? AccountName1 { get; set; }

        public string? AccountName2 { get; set; }

        public string? AccountName3 { get; set; }

        public string? AccountName4 { get; set; }
    }
}
