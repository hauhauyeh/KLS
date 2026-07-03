using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    // Item AvgCost Review (revaluation triage) — raw feed row. Triage verdicts
    // (Cost Delta / % Change / Revalue Impact / Cost Age / Status Tag) are derived
    // client-side so the reviewer can tune tolerance thresholds live.
    public class RptItemAvgCostReviewRow
    {
        [Key]
        public int ItemId { get; set; }

        public string? ItemCode { get; set; }
        public string? ItemName { get; set; }
        public int? CategoryId { get; set; }
        public string? Category { get; set; }
        public string? CategoryPath { get; set; }   // '/ancestorId/.../categoryId/' for client subtree filter

        public decimal? OnHand { get; set; }         // Item.LCloseQty
        public decimal? CurAvgCost { get; set; }     // Item.LAvgCost
        public decimal? CurInvValue { get; set; }    // Item.LInventoryValue

        public decimal? RecentCost { get; set; }     // RN=1 landed cost per base unit
        public decimal? RecentBaseCost { get; set; } // RN=1 raw base cost (no freight/duty)
        public DateOnly? LastPurchaseDate { get; set; }
        public string? LastVendor { get; set; }
        public decimal? RN2Cost { get; set; }        // RN=2 landed cost (believability check)
    }
}
