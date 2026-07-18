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

        public string Unit { get; set; }

        [Column(TypeName = "decimal(18, 6)")]
        public decimal FactorToBase { get; set; }

        // Numerator of the unit ratio (denominator = FactorToBase):
        //   BaseQty = Qty * MultipleToBase / FactorToBase
        // Default 1 = identity (today's Qty / FactorToBase). Combine-up units store MultipleToBase = N,
        // FactorToBase = 1. DB CHECKs enforce ( > 0 ) and ( MultipleToBase = 1 OR FactorToBase = 1 ).
        // Initialized to 1 so EF inserts a value that satisfies the CHECK when not explicitly set.
        public int MultipleToBase { get; set; } = 1;

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? PricePercentToBase { get; set; }

        public bool IsBaseUnit { get; set; }
        public bool IsDefaultSalesUnit { get; set; }

        public string? Barcode { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? RecentCost { get; set; }
        // Pure item cost (no landed cost) — RecentCost minus the landed-cost share.
        // Written by ItemUnit_UpdateRecentCost; NULL until the item has purchase history.
        [Column(TypeName = "decimal(18, 4)")]
        public decimal? RecentBaseCost { get; set; }
        [Column(TypeName = "decimal(18, 4)")]
        public decimal? P1 { get; set; }
        [Column(TypeName = "decimal(18, 4)")]
        public decimal? MSRP { get; set; }
        [Column(TypeName = "decimal(18, 4)")]
        public decimal? MarketPrice { get; set; }

        public bool Inactive { get; set; }

        [NotMapped]
        public string DisplayUnit
        {
            get
            {
                // If factor is 1 (base unit), show only the unit
                if (FactorToBase == 1)
                    return Unit;

                // Otherwise show factor + unit
                return $"{FactorToBase:0.####} {Unit}";
            }
        }
    }
}
