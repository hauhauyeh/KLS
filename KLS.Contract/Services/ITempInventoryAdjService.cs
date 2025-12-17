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
        IEnumerable<TempInventoryItem>? GetTempAdjItems(TempInventoryReq tempReq);

        TempInventoryItem CreateTempItem(TempInventoryItem tempItem);

        void UpdateTempItem(TempInventoryAdj tempAdj);

        void DeleteTempItem(int tempAdjId);

        void ClearTempItem(TempInventoryReq tempReq);
    }
}
