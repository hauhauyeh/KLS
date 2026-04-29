using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IInventoryAdjService
    {
        PagingResponse<InventoryAdjList> GetPagedList(InventoryAdjListReq inventoryAdjListReq);

        IEnumerable<InventoryAdjList> GetHistoryByItem(int itemId);

        InventoryAdj GetById(int adjId);

        int Save(InventoryAdj inventoryAdj);

        void Inject(int adjId);

        void Delete(int adjId);

        void DeleteDetail(int adjDetailId);

        void UpdateNotes(InventoryAdj inventoryAdj);

        void UpdateDetailNotes(InventoryAdjList inventoryAdjList);

        InventoryClosingDetail QtyAdj(QtyAdjReq adjReq);

        InventoryClosingDetail GetClosingQty(int itemId);
    }
}
