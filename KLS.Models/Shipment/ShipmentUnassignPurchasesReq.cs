using System.Collections.Generic;

namespace KLS.Models
{
    public class ShipmentUnassignPurchasesReq
    {
        public List<int> ShipmentPurchaseIds { get; set; } = new();
    }
}
