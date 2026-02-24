using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IShipmentRepository : IRepository<Shipment>
    {
        IQueryable<ShipmentList> GetPagedList(ShipmentListReq shipmentListReq);

        int Count(ShipmentListReq shipmentListReq);

        void Allocation(int purchaseId);

        void UnAllocation(int shipmentPurchaseId);
    }
}
