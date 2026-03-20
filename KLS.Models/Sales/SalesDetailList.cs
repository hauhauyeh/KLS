using KLS.Common;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class SalesDetailList
    {
        [Key]
        public int SalesDetailId { get; set; }
        public int SalesId { get; set; }

        public decimal? OrdQty { get; set; }
        public decimal? ShipQty { get; set; }
        public decimal? BillQty { get; set; }

        public string? Unit { get; set; }

        public decimal? UnitPrice { get; set; }
        public decimal? ExtTotal => Utilities.Rounding((BillQty ?? 0m) * (UnitPrice ?? 0m), 2);

        public string? Notes { get; set; }

        public string? ItemName { get; set; }
    }
}
