using System;

namespace KLS.Models
{
    public class ShipmentManagerListRow
    {
        public int ContainerSeq { get; set; }

        public int ShipmentId { get; set; }

        public string ShipmentType { get; set; } = string.Empty;

        public string? ContainerNo { get; set; }

        public string? ContainerType { get; set; }

        public int PayeeId { get; set; }

        public string PayeeName { get; set; } = string.Empty;

        public string? Origin { get; set; }

        public string? Destination { get; set; }

        public DateOnly? ETD { get; set; }

        public DateOnly? ETA { get; set; }

        public string Status { get; set; } = string.Empty;

        public string? DutyStatus { get; set; }

        public string? Notes { get; set; }

        public decimal? TotalCharges { get; set; }

        public string? FactorPO { get; set; }

        public string? VendorDocNumber { get; set; }

        public string? ShipperName { get; set; }

        public string? MajorItem { get; set; }

        public string? CustomerName { get; set; }

        public bool AreChargesComplete { get; set; }

        public DateTime? ChargesCompletedAt { get; set; }

        public int? ChargesCompletedBy { get; set; }

        public int AssignedBillCount { get; set; }

        public bool IsLocked { get; set; }
    }
}
