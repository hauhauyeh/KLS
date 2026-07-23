namespace KLS.Models
{
    public class AllocationMethodSummary
    {
        public string Method { get; set; } = "";
        public int TotalItems { get; set; }
        public int ItemsWithData { get; set; }
        public int ItemsMissing { get; set; }
        public int Coverage { get; set; }
    }

    public class AllocationMissingItem
    {
        public string Method { get; set; } = "";
        public int ItemId { get; set; }
        public string ItemCode { get; set; } = "";
        public string ItemName { get; set; } = "";
        public string MissingField { get; set; } = "";
    }

    public class AllocationValidationResult
    {
        public List<AllocationMethodSummary> Methods { get; set; } = new();
    }

    public class ShipmentReallocationSkip
    {
        public int PurchaseId { get; set; }

        public int PurchaseNumber { get; set; }

        public string Action { get; set; } = "";

        public string Reason { get; set; } = "";
    }

    public class ShipmentReallocationCleanupRes
    {
        public int ShipmentId { get; set; }

        public string Status { get; set; } = "";

        public List<int> ReallocatedPurchaseIds { get; set; } = new();

        public List<int> ReallocatedPurchaseNumbers { get; set; } = new();

        public List<ShipmentReallocationSkip> Skipped { get; set; } = new();

        public int ReallocatedCount { get; set; }

        public int SkippedCount { get; set; }

        public string Message { get; set; } = "";
    }
}
