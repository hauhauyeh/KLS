using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
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

        public void UpdateNotes(Purchase purchase)
        {
            var existing = GetById(purchase.PurchaseId);

            if (existing != null)
            {
                existing.Notes = purchase.Notes;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.Purchases.Update(existing);
                Uow.Commit();
            }
        }

        public void UpdateVendorDocNumber(Purchase purchase)
        {
            var existing = GetById(purchase.PurchaseId);

            if (existing != null)
            {
                existing.VendorDocNumber = purchase.VendorDocNumber;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.Purchases.Update(existing);
                Uow.Commit();
            }
        }
    }
}
