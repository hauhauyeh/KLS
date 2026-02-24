using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptSalesTax
    {
        [Key]
        public string? PayeeName { get; set; }

        public decimal? TaxableSales { get; set; }

        public decimal? NonTaxableSales { get; set; }

        public decimal? NonSales { get; set; }

        public decimal? TaxTotal { get; set; }
    }
}
