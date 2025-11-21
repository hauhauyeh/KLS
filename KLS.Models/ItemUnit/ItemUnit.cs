using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemUnit
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int ItemUnitId { get; set; }
        public int ItemId { get; set; }
        public int UnitId { get; set; }

        public decimal FactorToBase { get; set; }
        public bool IsBaseUnit { get; set; }
        public bool IsDefaultSalesUnit { get; set; }
        public bool IsDefaultPurchaseUnit { get; set; }

        public string? Barcode { get; set; }

        public decimal? RecentCost { get; set; }
        public decimal? FreightCost { get; set; }
        public decimal? P1 { get; set; }
        public decimal? MSRP { get; set; }
        public decimal? MarketPrice { get; set; }
    }
}
