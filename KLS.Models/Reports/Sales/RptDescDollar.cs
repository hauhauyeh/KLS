using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models.Reports
{
    public class RptDescDollar
    {
        [Key]
        public int ItemId { get; set; }

        public string? ItemName { get; set; }

        public string? Unit { get; set; }

        public decimal? TotalQty { get; set; }

        public decimal? TotalPrice { get; set; }
    }
}
