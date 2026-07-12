using System.Collections.Generic;

namespace KLS.Models
{
    // Request body for POST api/admin/Shipments/{shipmentId}/AssignBills (Multi-Bill Assign flow).
    // Batch-assigns these bills to the route's shipment. The service dedups and validates non-empty;
    // Shipment_AssignBills re-validates every rule (bill stage, not shipment bill, not already
    // assigned, not locked/paid, consolidated bill not locked) and is the atomic write boundary.
    public class AssignBillsReq
    {
        public List<int> PurchaseIds { get; set; } = new();
    }
}
