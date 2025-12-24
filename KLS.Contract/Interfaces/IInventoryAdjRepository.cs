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
        IQueryable<InventoryAdjList> GetPagedList(InventoryAdjListReq inventoryAdjListReq);

        int Count(InventoryAdjListReq inventoryAdjListReq);

        int Save(InventoryAdj inventoryAdj);

        void Inject(int adjId);
    }
}
