using KLS.Common;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TargetQuotePrice
    {
        [Key]
        public int ItemQuoteId { get; set; }

        public int ItemUnitId { get; set; }

        public string? Unit { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? MarkupPercent { get; set; }

        public decimal? TargetPrice { get; set; }

        public bool IsFixed { get; set; }

        public string? PayeeName { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? BaseMarkup { get; set; }

        public decimal? P1 { get; set; }

        public bool IsBaseToRecentCost { get; set; }

        public decimal? RecentCost { get; set; }

        public decimal? Payee30Volume { get; set; }

        public decimal? DefaultPrice
        {
            get
            {
                return Utilities.Rounding(P1 * (1 + BaseMarkup), 2);
            }
        }

        public decimal? FinalPrice
        {
            get
            {
                var basePrice = (IsBaseToRecentCost ? RecentCost : P1) ?? 0m;
                decimal? price = null;

                if (IsFixed)
                    price = TargetPrice;
                else if (MarkupPercent.HasValue)
                    price = Utilities.Rounding(basePrice * (1 + MarkupPercent.Value), 2);

                // If you want to treat 0 as "no price"
                return (price.HasValue && price.Value != 0m) ? price : null;
            }
        }

        [NotMapped]
        public decimal? FinalPriceUpdate { get; set; }
    }
}
