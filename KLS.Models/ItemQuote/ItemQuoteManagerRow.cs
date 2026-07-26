using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class ItemQuoteManagerRow
    {
        public string RowKey { get; set; } = string.Empty;

        public string Source { get; set; } = string.Empty;

        public bool IsEditable { get; set; }

        public bool IsSharedVisibleInCustomerGuide { get; set; }

        public int PayeeId { get; set; }

        public int? ShareQuoteId { get; set; }

        public int ItemId { get; set; }

        public int ItemUnitId { get; set; }

        public int? TempQuoteId { get; set; }

        public int? OwnItemQuoteId { get; set; }

        public int? SharedItemQuoteId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? Unit { get; set; }

        public decimal? RecentCost { get; set; }

        public decimal? P1 { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? BaseMarkup { get; set; }

        public bool IsBaseToRecentCost { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? OwnMarkupPercent { get; set; }

        public decimal? OwnTargetPrice { get; set; }

        public bool OwnIsFixed { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? SharedMarkupPercent { get; set; }

        public decimal? SharedTargetPrice { get; set; }

        public bool SharedIsFixed { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? MarkupPercent { get; set; }

        public decimal? TargetPrice { get; set; }

        public bool IsFixed { get; set; }

        public decimal? FinalPrice { get; set; }

        public string? FinalPriceReason { get; set; }

        [NotMapped]
        public int PriceDecimals { get; set; } = 2;
    }
}
