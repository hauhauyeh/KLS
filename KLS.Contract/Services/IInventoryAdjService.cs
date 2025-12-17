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
        PagingResponse<InventoryAdjList> GetAllInventoryAdj(InventoryAdjListReq inventoryAdjListReq);

        InventoryAdj GetById(int adjId);

        IEnumerable<InventoryAdjList> SaveInventoryAdj(InventoryAdj inventoryAdj);

        void InjectInventoryAdj(int adjId);

        void DeleteInventoryAdj(int adjId);

        void UpdateNotes(InventoryAdj inventoryAdj);

        void UpdateDetailNotes(InventoryAdjList inventoryAdjList);
    }
}
