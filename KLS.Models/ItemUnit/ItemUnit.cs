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

        //[Column(TypeName = "decimal(18, 4)")]
        //public decimal? PricePercentToBase { get; set; }

        public bool IsBaseUnit { get; set; }
        public bool IsDefaultSalesUnit { get; set; }

        public string? Barcode { get; set; }

        public decimal? RecentCost { get; set; }
        public decimal? FreightCost { get; set; }
        public decimal? P1 { get; set; }
        public decimal? MSRP { get; set; }
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
