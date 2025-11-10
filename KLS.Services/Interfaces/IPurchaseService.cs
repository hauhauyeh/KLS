using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IPurchaseService
    {
        PagingResponse<PurchaseList> GetAllPurchase(PurchaseListReq purchaseListReq);

        Purchase GetById(int purchaseId);

        void UpdateNotes(int purchaseId, string? notes);

        void UpdateDocNumber(int purchaseId, string? docNumber);

        void UpdateInvoiceDate(int purchaseId, DateOnly? invoiceDate);

        void UpdateCommission(int purchaseId, decimal? commission);

        void UpdatePallet(int purchaseId, int? palletCount);

        void UpdateNameDate(PurchaseUpdateReq updateReq);

        Purchase Checkout(PurchaseCheckoutReq checkoutReq);

        void UpdatePartially(int purchaseId);

        void InjectPurchase(PurchaseInjectReq injectReq);

        void DeletePurchase(int purchaseId);

        void UploadBillPDF(PDFUploadReq pdfUploadReq);
    }
}
