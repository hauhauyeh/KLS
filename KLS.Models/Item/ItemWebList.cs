using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemWebList
    {
        [Key]
        public int ItemId { get; set; }
        public string ItemCode { get; set; }
        public string ItemName { get; set; }
        public string? ItemName2 { get; set; }
        public string? ItemLongDesc { get; set; }

        public string? SetPacking { get; set; }
        public string? PackSize { get; set; }
        public decimal? LCloseQty { get; set; }
        public DateOnly? ExpiryDate { get; set; }

        public string? PrimaryImageUrl { get; set; }

        public string? PromoBadgeText { get; set; }

        public decimal? BogoConditionQty { get; set; }
        public decimal? BogoAfterPromoPrice { get; set; }
        public decimal? BogoSavings { get; set; }

        public ICollection<ItemWebUnitList>? ItemUnits { get; set; }
    }
}
