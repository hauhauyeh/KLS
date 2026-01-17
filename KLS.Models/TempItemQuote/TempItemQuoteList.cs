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


        public string? ItemName { get; set; }

        public string? ItemCode { get; set; }

        public string? Unit { get; set; }

        public decimal? RecentCost { get; set; }

        public decimal? P1 { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? BaseMarkup { get; set; }

        public bool IsBaseToRecentCost { get; set; }


        public decimal? FinalPrice
        {
            get
            {
                var markup = MarkupPercent ?? BaseMarkup ?? 0m;
                var basePrice = (IsBaseToRecentCost ? RecentCost : P1) ?? 0m;

                return Math.Round(basePrice * (1 + markup), 2);

                //var basePrice = string.IsNullOrEmpty(CustDefBasePriceId) ? P1 : RecentCost;
            }
        }
    }
}
