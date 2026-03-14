using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemWebUnitList
    {
        [Key]
        public int ItemUnitId { get; set; }

        public string? Unit { get; set; }

        public string? Barcode { get; set; }

        public bool IsBaseUnit { get; set; }

        public bool IsDefaultSalesUnit { get; set; }

        public decimal? MSRP { get; set; }

        public decimal? MarketPrice { get; set; }

        public decimal? Price { get; set; }

        public decimal? Discount { get; set; }
    }
}
