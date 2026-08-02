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

        protected void CancelLinkedDropShipPurchaseDelete(Purchase purchase, int purchaseId)
        {
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

                Uow.Sales.Find(s => s.SalesId == purchase.DropShipSalesId)
                    .ExecuteUpdate(su => su
                        .SetProperty(s => s.IsDropShip, false)
                        .SetProperty(s => s.DropShipPurchaseId, (int?)null)
                        .SetProperty(s => s.StageId, 0)
                        .SetProperty(s => s.UpdatedAt, DateTime.UtcNow));

                Uow.Purchases.Find(c => c.PurchaseId == purchaseId).ExecuteDelete();
            });
        }
    }
}
