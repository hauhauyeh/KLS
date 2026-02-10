using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class CustomerPaymentStatement
    {
        public string? PayeeName { get; set; }

        [Key]
        public DateOnly? ShipMonth { get; set; }

        public decimal? AmountDue { get; set; }

        public decimal? Perc1 { get; set; }

        public decimal? Perc2 { get; set; }

        public decimal? Perc3 { get; set; }

        public decimal? Perc4 { get; set; }

        public decimal? Perc5 { get; set; }
    }
}
