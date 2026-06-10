using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class VendorPurchaseHistoryPanelRow
    {
        [Key]
        public int ItemId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? SetPacking { get; set; }

        public string? CategoryName { get; set; }

        public int? CategorySort { get; set; }

        public DateOnly? LastPurchaseDate { get; set; }

        public decimal? LastPurchaseQty { get; set; }

        // Stage name of the most recent purchase row: Ordered / Partially
        // Shipped / Shipped / Partially Received / Received / Billed.
        // UI renders as a small chip alongside LastPurchaseDate so the user
        // sees whether the most recent activity is still in flight.
        public string? LastPurchaseStage { get; set; }

        public decimal? TotalQty1Y { get; set; }

        public decimal? TotalQty3M { get; set; }

        public int? PurchaseCount1Y { get; set; }
    }
}
