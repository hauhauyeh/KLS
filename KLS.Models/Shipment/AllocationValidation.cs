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

    public class AllocationResultItem
    {
        public string ChargeType { get; set; } = "";
        public string RequestedMethod { get; set; } = "";
        public string UsedMethod { get; set; } = "";
        public int ItemCount { get; set; }
        public int FallbackCount { get; set; }
    }

    public class ReallocateReq
    {
        public int PurchaseId { get; set; }
        public bool RefreshVolume { get; set; }
        public List<ChargeMethodOverride>? Charges { get; set; }
    }

    public class ChargeMethodOverride
    {
        public int ChargeId { get; set; }
        public string AllocationMethod { get; set; } = "";
    }

    public class ReallocateResponse
    {
        public List<AllocationResultItem> Results { get; set; } = new();
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
