using System;

namespace KLS.Models
{
    public class ShipmentConfirmChargesCompleteResult
    {
        public int ShipmentId { get; set; }

        public int AssignedBillCount { get; set; }

        public int ReallocatedCount { get; set; }

        public int GeneratedOrUpdatedApBillCount { get; set; }

        public bool AreChargesComplete { get; set; }

        public DateTime? ChargesCompletedAt { get; set; }

        public int? ChargesCompletedBy { get; set; }

        public string Status { get; set; } = "";

        public string Message { get; set; } = "";
    }
}
