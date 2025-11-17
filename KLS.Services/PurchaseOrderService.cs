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
            var purchaseOrders = Uow.PurchaseOrders.GetAllPurchaseOrders(purchaseOrderReq);

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

        public PurchaseOrderList? GetListById(int poId)
        {
            var listReq = new PurchaseOrderReq
            {
                Id = poId
            };

            return Uow.PurchaseOrders.GetAllPurchaseOrders(listReq).AsEnumerable().
                FirstOrDefault();
        }

        //public void UpdateNotes(PurchaseOrder purchaseOrder)
        //{
        //    var existing = GetById(purchaseOrder.POId);

        //    if (existing != null)
        //    {
        //        existing.Notes = purchaseOrder.Notes;
        //        existing.UpdatedAt = DateTime.UtcNow;

        //        Uow.PurchaseOrders.Update(existing);
        //        Uow.Commit();
        //    }
        //}

        public void UpdateNotes(int poId, string? notes)
        {
            Uow.PurchaseOrders.Find(c => c.POId == poId).ExecuteUpdate(setters => setters
            .SetProperty(x => x.Notes, x => notes)
            .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
        }

        public void UpdateContainerNumber(PurchaseOrder purchaseOrder)
        {
            var existing = GetById(purchaseOrder.POId);

            if (existing != null)
            {
                existing.ContainerNumber = purchaseOrder.ContainerNumber;
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

        public PurchaseOrderList? Checkout(PurchaseOrderCheckoutReq checkoutReq)
        {
            var poId = Uow.PurchaseOrders.Checkout(checkoutReq);

            return GetListById(poId);
        }

        public void DeletePurchaseOrder(int poId)
        {
            var purchaseOrder = GetById(poId);

            if (purchaseOrder != null && !purchaseOrder.PurchaseId.HasValue)
            {
                Uow.PurchaseOrders.Find(c => c.POId == poId).ExecuteDelete();
            }
        }

        public void SaveAdvancePayment(POAdvancePaymentReq advancePaymentReq)
        {
            Uow.PurchaseOrders.SaveAdvancePayment(advancePaymentReq);
        }

        public void DeleteAdvancePayment(int poId)
        {
            Uow.PurchaseOrders.DeleteAdvancePayment(poId);
        }

        public IEnumerable<PODetail> GetPODetail(int poId)
        {
            return Uow.PurchaseOrders.GetPODetail(poId);
        }

        public PurchaseOrderList? CopyToBill(POCopyToBillReq copyToBillReq)
        {
            Uow.PurchaseOrders.CopyToBill(copyToBillReq);

            return GetListById(copyToBillReq.POId);
        }
    }
}
