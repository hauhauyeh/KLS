using KLS.Models.Reports;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class EmailPricesheet
    {
        public ICollection<RptPricesheet>? Pricesheet { get; set; }

        public string? PayeeName { get; set; }

        public Company? Company { get; set; }
    }
}
