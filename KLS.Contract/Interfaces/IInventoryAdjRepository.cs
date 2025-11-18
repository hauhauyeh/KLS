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
        IQueryable<InventoryAdjList> GetInventoryAdjs(InventoryAdjListReq inventoryAdjListReq);

        int CountAllInventoryAdjs(InventoryAdjListReq inventoryAdjListReq);
    }
}
