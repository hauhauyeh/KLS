using System;
using System.Collections.Generic;

namespace KLS.Models
{
    public class ShipmentChargeBillSaveReq
    {
        public int ShipmentChargeBillId { get; set; }

        public int ShipmentId { get; set; }

        public int VendorPayeeId { get; set; }

        public string? VendorDocNumber { get; set; }

        public DateOnly? BillDate { get; set; }

        public string? Notes { get; set; }

        public bool ConvertLegacyCharges { get; set; }

        public List<ShipmentChargeBillLineReq> Lines { get; set; } = new();
    }

    public class ShipmentChargeBillLineReq
    {
        public int ShipmentChargeBillLineId { get; set; }

        public string ChargeType { get; set; } = string.Empty;

        public decimal ChargeAmount { get; set; }

        public string? Notes { get; set; }
    }

    public class ShipmentChargeBillDto
    {
        public int ShipmentChargeBillId { get; set; }

        public int ShipmentId { get; set; }

        public int VendorPayeeId { get; set; }

        public string? VendorName { get; set; }

        public string? VendorDocNumber { get; set; }

        public DateOnly? BillDate { get; set; }

        public int? PurchaseId { get; set; }

        public int? PurchaseNumber { get; set; }

        public string State { get; set; } = "Draft";

        public decimal TotalAmount { get; set; }

        public bool IsReadOnly { get; set; }

        public string? Notes { get; set; }

        public DateTime CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public List<ShipmentChargeBillLineDto> Lines { get; set; } = new();
    }

    public class ShipmentChargeBillLineDto
    {
        public int ShipmentChargeBillLineId { get; set; }

        public int ShipmentChargeBillId { get; set; }

        public string ChargeType { get; set; } = string.Empty;

        public decimal ChargeAmount { get; set; }

        public string? Notes { get; set; }
    }
}
