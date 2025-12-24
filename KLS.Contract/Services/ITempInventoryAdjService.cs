using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempInventoryAdjService
    {
        IEnumerable<TempInventoryItem>? GetList(TempInventoryReq tempReq);

        TempInventoryItem Create(TempInventoryItem tempItem);

        void Update(TempInventoryAdj tempAdj);

        void Delete(int tempAdjId);

        void Clear(TempInventoryReq tempReq);
    }
}
