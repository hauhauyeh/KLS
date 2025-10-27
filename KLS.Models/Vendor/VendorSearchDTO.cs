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

        public int? AccountId1 { get; set; }

        public string? AccountId2 { get; set; }

        public string? AccountId3 { get; set; }

        public string? AccountId4 { get; set; }

        public string? AccountName1 { get; set; }

        public string? AccountName2 { get; set; }

        public string? AccountName3 { get; set; }

        public string? AccountName4 { get; set; }
    }
}
