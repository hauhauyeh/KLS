using System;
using System.Collections.Generic;

namespace KLS.Models
{
    public class SharedShipmentChargeBillSaveReq
    {
        public int SharedShipmentChargeBillId { get; set; }

        public int VendorPayeeId { get; set; }

        public string? VendorDocNumber { get; set; }

        public DateOnly? BillDate { get; set; }

        public string? Notes { get; set; }

        public SharedShipmentChargeBillLineReq? Line { get; set; }

        public List<SharedShipmentChargeBillSplitReq> Splits { get; set; } = new();
    }

    public class SharedShipmentChargeBillLineReq
    {
        public int SharedShipmentChargeBillLineId { get; set; }

        public string ChargeType { get; set; } = string.Empty;

        public decimal ChargeAmount { get; set; }

        public string? Notes { get; set; }
    }

    public class SharedShipmentChargeBillSplitReq
    {
        public int SharedShipmentChargeBillSplitId { get; set; }

        public int ShipmentId { get; set; }

        public string SplitMethod { get; set; } = string.Empty;

        public decimal? SplitPercent { get; set; }

        public decimal SplitAmount { get; set; }

        public string? GeneratedVendorDocNumber { get; set; }

        public string? Notes { get; set; }
    }

    public class SharedShipmentChargeBillListDto
    {
        public int SharedShipmentChargeBillId { get; set; }

        public int VendorPayeeId { get; set; }

        public string? VendorName { get; set; }

        public string? VendorDocNumber { get; set; }

        public DateOnly? BillDate { get; set; }

        public string Status { get; set; } = string.Empty;

        public string? ChargeType { get; set; }

        public decimal SourceAmount { get; set; }

        public int SplitCount { get; set; }

        public int AppliedChildCount { get; set; }

        public bool IsReadOnly { get; set; }

        public bool CanApply { get; set; }

        public string? ReadOnlyReason { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }
    }

    public class SharedShipmentChargeBillDto : SharedShipmentChargeBillListDto
    {
        public string? Notes { get; set; }

        public SharedShipmentChargeBillLineDto? Line { get; set; }

        public List<SharedShipmentChargeBillSplitDto> Splits { get; set; } = new();
    }

    public class SharedShipmentChargeBillLineDto
    {
        public int SharedShipmentChargeBillLineId { get; set; }

        public int SharedShipmentChargeBillId { get; set; }

        public string ChargeType { get; set; } = string.Empty;

        public decimal ChargeAmount { get; set; }

        public string? Notes { get; set; }
    }

    public class SharedShipmentChargeBillSplitDto
    {
        public int SharedShipmentChargeBillSplitId { get; set; }

        public int SharedShipmentChargeBillId { get; set; }

        public int ShipmentId { get; set; }

        public string? ShipmentNumber { get; set; }

        public string SplitMethod { get; set; } = string.Empty;

        public decimal? SplitPercent { get; set; }

        public decimal SplitAmount { get; set; }

        public string? GeneratedVendorDocNumber { get; set; }

        public int? GeneratedShipmentChargeBillId { get; set; }

        public string? Notes { get; set; }
    }

    public class SharedShipmentChargeBillActionResult
    {
        public int SharedShipmentChargeBillId { get; set; }

        public string Status { get; set; } = string.Empty;

        public int GeneratedChildCount { get; set; }

        public int RemovedChildCount { get; set; }

        public int AffectedShipmentCount { get; set; }

        public string Message { get; set; } = string.Empty;
    }
}
