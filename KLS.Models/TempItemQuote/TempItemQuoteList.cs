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
    public class TempItemQuoteList
    {
        [Key]
        public int TempQuoteId { get; set; }

        public int PayeeId { get; set; }

        public int ItemId { get; set; }

        public int ItemUnitId { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? MarkupPercent { get; set; }

        public decimal? TargetPrice { get; set; }

        public decimal? NewPrice { get; set; }

        public decimal? OldPrice { get; set; }

        public bool IsFixed { get; set; }


        public string? ItemName { get; set; }

        public string? ItemCode { get; set; }

        public string? Unit { get; set; }

        public decimal? RecentCost { get; set; }

        public decimal? P1 { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? BaseMarkup { get; set; }

        public bool IsBaseToRecentCost { get; set; }

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

                //var basePrice = string.IsNullOrEmpty(CustDefBasePriceId) ? P1 : RecentCost;
            }
        }

        [NotMapped]
        public decimal? FinalPriceUpdate { get; set; }

        [NotMapped]
        public decimal? MarkupPercentUpdate { get; set; }
    }
}
