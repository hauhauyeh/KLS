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

        public IQueryable<Purchase> GetAllPurchase()
        {
            return Uow.Purchases.GetAll();
        }

        public Purchase GetById(int purchaseId)
        {
            return Uow.Purchases.GetById(purchaseId);
        }

        public PagingResponse<PurchaseList> GetAllPurchase(PurchaseListReq purchaseListReq)
        {
            var purchaselist = Uow.Purchases.GetPurchase(purchaseListReq);

            var totalRecords = Uow.Purchases.CountAllPurchase(purchaseListReq);

            return new PagingResponse<PurchaseList>(totalRecords, purchaseListReq.Pageno, purchaseListReq.Pagesize)
            {
                RowData = purchaselist,
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
