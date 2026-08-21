using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class BaseService
    {
        protected IUnitOfWork Uow { get; }

        public BaseService(IUnitOfWork uow)
        {
            Uow = uow;
        }

        protected bool IsVisibleCustomer(int payeeId)
        {
            if (!UserContext.IsSalesRole)
                return true;

            return Uow.Customers.Exists(c => c.PayeeId == payeeId && c.SalesRepId == UserContext.EmpId);
        }

        protected bool IsVisibleSales(int salesId)
        {
            if (!UserContext.IsSalesRole)
                return true;

            var shipId = Uow.Sales.Find(s => s.SalesId == salesId)
                .Select(s => s.ShipId)
                .FirstOrDefault();

            return shipId.HasValue && IsVisibleCustomer(shipId.Value);
        }

        protected bool IsVisibleCustomerPayment(int customerPaymentId)
        {
            if (!UserContext.IsSalesRole)
                return true;

            var payeeId = Uow.CustomerPayments.Find(p => p.CustomerPaymentId == customerPaymentId)
                .Select(p => (int?)p.PayeeId)
                .FirstOrDefault();

            return payeeId.HasValue && IsVisibleCustomer(payeeId.Value);
        }

        protected void EnsureVisibleCustomer(int payeeId)
        {
            if (!IsVisibleCustomer(payeeId))
                throw new UnauthorizedAccessException("Customer is outside the current user's sales scope.");
        }

        protected void EnsureVisibleSales(int salesId)
        {
            if (!IsVisibleSales(salesId))
                throw new UnauthorizedAccessException("Order is outside the current user's sales scope.");
        }

        protected void EnsureVisibleCustomerPayment(int customerPaymentId)
        {
            if (!IsVisibleCustomerPayment(customerPaymentId))
                throw new UnauthorizedAccessException("Payment is outside the current user's sales scope.");
        }

        protected void CancelLinkedDropShipPODelete(Purchase purchase, int purchaseId)
        {
            if (!purchase.IsDropShip || purchase.DropShipSalesId == null)
                throw new ArgumentException("This is not a linked drop-ship PO.");

            if (purchase.IsLocked)
                throw new ArgumentException("Locked drop-ship PO cannot be deleted.");

            if (purchase.StageId is null or < 1 or > 3)
                throw new ArgumentException("Only pre-bill drop-ship POs can be deleted from PO Manager.");

            Uow.ExecuteInTransaction(() =>
            {
                var linkedSales = Uow.Sales.Find(s => s.SalesId == purchase.DropShipSalesId)
                    .Select(s => new { s.SalesId, s.SalesNumber })
                    .SingleOrDefault();

                if (linkedSales == null)
                    throw new ArgumentException("Linked drop-ship sales order was not found.");

                var hasPostedJournal = Uow.Transactions.Find(t =>
                        (t.SourceDocType == "Purchase" && t.SourceDocNumber == purchase.PurchaseNumber)
                        || (t.SourceDocType == "Sales" && t.SourceDocNumber == linkedSales.SalesNumber))
                    .Any();

                if (hasPostedJournal)
                    throw new ArgumentException("Drop-ship PO has posted journal rows. Delete from Bill Manager instead.");

                RestoreSalesFromDeletedDropShipPurchase(purchase);

                Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteDelete();
            });
        }

        protected void CancelLinkedDropShipBillDelete(Purchase purchase, int purchaseId)
        {
            if (!purchase.IsDropShip || purchase.DropShipSalesId == null)
                throw new ArgumentException("This is not a linked drop-ship Bill.");

            if (purchase.IsLocked)
                throw new ArgumentException("Locked drop-ship Bill cannot be deleted.");

            if (purchase.StageId != 6)
                throw new ArgumentException("Only billed drop-ship Bills can be deleted from Bill Manager.");

            Uow.ExecuteInTransaction(() =>
            {
                var linkedSales = Uow.Sales.Find(s => s.SalesId == purchase.DropShipSalesId)
                    .Select(s => new { s.SalesId, s.SalesNumber })
                    .SingleOrDefault();

                if (linkedSales == null)
                    throw new ArgumentException("Linked drop-ship sales order was not found.");

                var txIds = Uow.Transactions.Find(t =>
                        (t.SourceDocType == "Purchase" && t.SourceDocNumber == purchase.PurchaseNumber)
                        || (t.SourceDocType == "Sales" && t.SourceDocNumber == linkedSales.SalesNumber))
                    .Select(t => t.TxId)
                    .ToList();

                if (txIds.Count > 0)
                {
                    Uow.TransactionDetails.Find(td => txIds.Contains(td.TxId)).ExecuteDelete();
                    Uow.Transactions.Find(t => txIds.Contains(t.TxId)).ExecuteDelete();
                }

                RestoreSalesFromDeletedDropShipPurchase(purchase);

                Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteDelete();
            });
        }

        protected void RestoreSalesFromDeletedDropShipPurchase(Purchase purchase)
        {
            if (purchase.DropShipSalesId == null)
                throw new ArgumentException("Linked drop-ship sales order was not found.");

            var linkedSales = Uow.Sales.Find(s => s.SalesId == purchase.DropShipSalesId)
                .Select(s => new { s.SalesId })
                .SingleOrDefault();

            if (linkedSales == null)
                throw new ArgumentException("Linked drop-ship sales order was not found.");

            Uow.Sales.Find(s => s.SalesId == linkedSales.SalesId)
                .ExecuteUpdate(su => su
                    .SetProperty(s => s.IsDropShip, false)
                    .SetProperty(s => s.DropShipPurchaseId, (int?)null)
                    .SetProperty(s => s.StageId, 0)
                    .SetProperty(s => s.UpdatedAt, DateTime.UtcNow));

            Uow.Sales.ClearDropShipOrderDetailQuantities(linkedSales.SalesId);
        }
    }
}
