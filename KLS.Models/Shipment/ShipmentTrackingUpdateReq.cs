using System;

namespace KLS.Models
{
    public class ShipmentTrackingUpdateReq
    {
        public DateOnly? ETD { get; set; }

        public DateOnly? ETA { get; set; }

        public string? DutyStatus { get; set; }

        public string? Notes { get; set; }
    }
}
