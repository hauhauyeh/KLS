using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class RPTPo
    {
        [Key]
        public int PurchaseId { get; set; }

        public int PurchaseNumber { get; set; }

        public int PayeeId { get; set; }

        public int? VendorDocNumber { get; set; }

        public DateOnly? PurchaseDate { get; set; }

        public DateOnly? ArrivalDate { get; set; }

        public decimal? PurchaseTotal { get; set; }

        public string? PayeeName { get; set; }

        public string? Address { get; set; }

        public string? City { get; set; }

        public string? State { get; set; }

        public string? ZipCode { get; set; }

        public string? Phone1 { get; set; }

        public string? Country { get; set; }
    }
}
