using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IInventoryAdjService
    {
        PagingResponse<InventoryAdjList> GetAllInventoryAdj(InventoryAdjListReq inventoryAdjListReq);

        IEnumerable<InventoryAdjList> SaveInventoryAdj(InventoryAdj inventoryAdj);

        void InjectInventoryAdj(int adjId);

        void DeleteInventoryAdj(int adjId);

        void UpdateNotes(InventoryAdj inventoryAdj);

        void UpdateDetailNotes(InventoryAdj inventoryAdj);
    }
}
