using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IInventoryAdjRepository : IRepository<InventoryAdj>
    {
        IQueryable<InventoryAdjList> GetAllInventoryAdj(InventoryAdjListReq inventoryAdjListReq);

        int CountAllInventoryAdj(InventoryAdjListReq inventoryAdjListReq);

        int SaveInventoryAdj(InventoryAdj inventoryAdj);

        void InjectInventoryAdj(int adjId);
    }
}
