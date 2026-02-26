using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IShipmentService
    {
        PagingResponse<ShipmentList> GetPagedList(ShipmentListReq shipmentListReq);

        IEnumerable<ShipmentList> GetOpenShipments();

        Shipment? GetById(int shipmentId);

        bool Exists(Shipment shipment);

        Shipment Create(Shipment shipment);

        Shipment Update(Shipment shipment);

        void UpdateNotes(Shipment shipment);

        void Delete(int shipmentId);

        Shipment? Reopen(int shipmentId);

        Shipment? GenerateBill(int shipmentId);

        void UnAllocation(int shipmentPurchaseId);

        IEnumerable<AssignedPurchase>? AssignedPurchases(int shipmentId);
    }
}
