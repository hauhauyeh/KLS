using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class VendorList
    {
        [Key]
        public int? PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public decimal? PayeeCurrent { get; set; }

        public decimal? Payee30 { get; set; }

        public decimal? Payee60 { get; set; }

        public decimal? Payee90 { get; set; }

        public decimal? PayeeOver90 { get; set; }

        public decimal? PayeeTotalDue { get; set; }

        public bool IsClosed { get; set; }
    }
}
