using KLS.Common;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempPurchaseService
    {
        IEnumerable<TempPurchaseItem>? GetList(TempPurchaseReq tempReq);

        TempPurchaseItem Create(TempPurchaseItem tempPurchase, EnumHelper.PurchaseDocType docType);

        TempPurchaseItem Update(TempPurchaseItem tempPurchase, EnumHelper.PurchaseDocType docType);

        TempPurchaseItem UpdateUnit(TempPurchaseItem tempPurchase);

        void Reorder(TempPurchaseReorderReq reorderReq);

        void Delete(int tempId);

        void Clear(TempPurchaseReq tempReq);
    }
}
