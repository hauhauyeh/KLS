using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IPurchaseOrderService
    {
        PagingResponse<POList> GetPagedList(POListReq purchaseOrderReq);

        POList? Checkout(POCheckoutReq checkoutReq);

        void Delete(int purchaseId);

        IEnumerable<PODetail> GetPODetail(int purchaseId);

        POList? CopyToBill(POCopyToBillReq copyToBillReq);

        string PrintPO(int purchaseId);

        PurchaseOrderEmailPdfResult EmailPdf(int purchaseId);

        POList? UpdateToBillStage(int purchaseId, PurchaseOrderConvertToBillReq? req);

    }
}
