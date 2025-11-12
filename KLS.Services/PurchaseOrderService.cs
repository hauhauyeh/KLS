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
    public class PurchaseOrderService : BaseService, IPurchaseOrderService
    {
        public PurchaseOrderService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<PurchaseOrderList> GetAllPurchaseOrders(PurchaseOrderReq purchaseOrderReq)
        {
            var purchaseOrders = Uow.PurchaseOrders.GetPurchaseOrders(purchaseOrderReq);

            var totalRecords = Uow.PurchaseOrders.CountAllPurchaseOrders(purchaseOrderReq);

            return new PagingResponse<PurchaseOrderList>(totalRecords, purchaseOrderReq.Pageno, purchaseOrderReq.Pagesize)
            {
                RowData = purchaseOrders,
            };
        }

        public PurchaseOrder GetById(int pOId)
        {
            return Uow.PurchaseOrders.GetById(pOId);
        }

        public void UpdateNotes(PurchaseOrder purchaseOrder)
        {
            var existing = GetById(purchaseOrder.POId);

            if (existing != null)
            {
                existing.Notes = purchaseOrder.Notes;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.PurchaseOrders.Update(existing);
                Uow.Commit();
            }
        }

        public void UpdateVendorDocNumber(PurchaseOrder purchaseOrder)
        {
            var existing = GetById(purchaseOrder.POId);

            if (existing != null)
            {
                existing.VendorDocNumber = purchaseOrder.VendorDocNumber;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.PurchaseOrders.Update(existing);
                Uow.Commit();
            }
        }

        public void InjectPurchaseOrder(PurchaseOrderInjectReq injectReq)
        {
            Uow.PurchaseOrders.InjectPurchaseOrder(injectReq);
        }

        public PurchaseOrder Checkout(PurchaseOrderCheckoutReq checkoutReq)
        {
            var poId = Uow.PurchaseOrders.Checkout(checkoutReq);

            return GetById(poId);
        }

        public void DeletePurchaseOrder(int poId)
        {
            var purchaseOrder = GetById(poId);

            if (purchaseOrder != null && !purchaseOrder.PurchaseId.HasValue)
            {
                Uow.PurchaseOrders.Find(c => c.POId == poId).ExecuteDelete();
            }
        }
    }
}
