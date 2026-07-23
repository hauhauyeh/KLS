using System;

namespace KLS.Models
{
    public class ShipmentReallocationCandidate
    {
        public int ShipmentId { get; set; }

        public int ShipmentPurchaseId { get; set; }

        public int PurchaseId { get; set; }

        public int PurchaseNumber { get; set; }

        public int? StageId { get; set; }

        public bool IsDropShip { get; set; }

        public bool IsLocked { get; set; }

        public decimal PaymentApplied { get; set; }

        public decimal DiscountApplied { get; set; }

        public DateTime? LastAllocAt { get; set; }

        public bool IsStale { get; set; }

        public bool IsMissingAllocation { get; set; }

        public string Action { get; set; } = "";

        public string Reason { get; set; } = "";
    }
}
