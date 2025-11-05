using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface ITempPurchaseService
    {
        IEnumerable<TempPurchaseItem>? GetTempPurchaseItems(TempPurchaseReq tempReq);

        TempPurchaseItem CreateTempPurchase(TempPurchaseItem tempPurchase);

        TempPurchaseItem UpdateTempPurchase(TempPurchaseItem tempPurchase);

        void DeleteTempPurchase(int tempId);

        void ClearTempPurchase(TempPurchaseReq tempReq);
    }
}
