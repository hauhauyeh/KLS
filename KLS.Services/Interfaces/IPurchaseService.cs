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

        void DeletePurchase(int purchaseId);

        void UploadBillPDF(PDFUploadReq pdfUploadReq);
    }
}
