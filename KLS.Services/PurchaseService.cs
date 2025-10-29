using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PurchaseService : BaseService, IPurchaseService
    {
        public PurchaseService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<PurchaseList> GetAllPurchase(PurchaseListReq purchaseListReq)
        {
            var bills = Uow.Purchases.GetAllPurchase(purchaseListReq);

            var totalRecords = Uow.Purchases.CountAllPurchase(purchaseListReq);

            // Get absolute path to wwwroot/BillPdf
            var billPDfPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "BillPdf");

            foreach (PurchaseList bill in bills)
            {
                var filePath = Path.Combine(billPDfPath, bill.PurchaseNumber + ".pdf");

                bill.IsPdfExist = File.Exists(filePath);
            }

            return new PagingResponse<PurchaseList>(totalRecords, purchaseListReq.Pageno, purchaseListReq.Pagesize)
            {
                RowData = bills,
            };
        }

        public Purchase GetById(int purchaseId)
        {
            return Uow.Purchases.GetById(purchaseId);
        }

        public void UpdateNotes(int purchaseId, string? notes)
        {
            var purchase = GetById(purchaseId);

            if (purchase != null)
            {
                purchase.Notes = notes;
                purchase.UpdatedAt = DateTime.UtcNow;

                Uow.Purchases.Update(purchase);
                Uow.Commit();
            }
        }

        public void UpdateDocNumber(int purchaseId, string? docNumber)
        {
            var purchase = GetById(purchaseId);

            if (purchase != null)
            {
                purchase.VendorDocNumber = docNumber;
                purchase.UpdatedAt = DateTime.UtcNow;

                Uow.Purchases.Update(purchase);
                Uow.Commit();
            }
        }

        public void DeletePurchase(int purchaseId)
        {
            var purchase = GetById(purchaseId);

            if (purchase != null && !purchase.IsLocked)
            {
                Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteDelete();
            }
        }
    }
}
