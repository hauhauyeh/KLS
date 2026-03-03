using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptPricesheet
    {
        [Key]
        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? ItemName2 { get; set; }

        public string? Unit { get; set; }

        public bool IsShared { get; set; }

        public decimal? Price { get; set; }

        public string? Cat0 { get; set; }

        public string? Cat1 { get; set; }

        public string? PackSize { get; set; }
    }
}
