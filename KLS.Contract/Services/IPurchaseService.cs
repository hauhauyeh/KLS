using KLS.Models;
using KLS.Models.Reports;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IPurchaseService
    {
        PagingResponse<PurchaseList> GetPagedList(PurchaseListReq purchaseListReq);

        Purchase GetById(int purchaseId);

        void UpdateNotes(int purchaseId, string? notes);

        bool DocNumberExists(int purchaseId, int payeeId, string? docNumber);

        PurchaseList? UpdateDocNumber(int purchaseId, string? docNumber);

        void UpdateInvoiceDate(int purchaseId, DateOnly? invoiceDate);

        void UpdateCommission(int purchaseId, decimal? commission);

        void UpdatePallet(int purchaseId, int? palletCount);

        PurchaseList? UpdateNameDate(PurchaseUpdateReq updateReq);

        PurchaseList? UpdateContainerNumber(int purchaseId, string? containerNumber);

        PurchaseList? UpdateFactorPO(int purchaseId, string? factorPO);

        PurchaseList? Checkout(PurchaseCheckoutReq checkoutReq);

        PurchaseList? UpdatePartially(int purchaseId);

        PurchaseList? DropShipRestrictedUpdate(int purchaseId);

        void Inject(PurchaseInjectReq injectReq);

        void Delete(int purchaseId);

        void UploadBillPDF(PDFUploadReq pdfUploadReq);

        bool IsBillPdfExist(int purchaseNumber);

        PurchaseSeePayment SeePayment(int purchaseId);

        IEnumerable<AssignedShipment>? AssignedShipments(int purchaseId, bool isShipment);

        void AssignShipment(POCopyToBillReq copyToBillReq);

        IEnumerable<PurchaseOpenBill>? GetOpenBills(int payeeId);

        IEnumerable<VendorPurchaseHistoryPanelRow> VendorPurchaseHistoryPanel(int payeeId);

        PurchaseDetailDto? GetPurchaseDetails(int purchaseId);
    }
}
