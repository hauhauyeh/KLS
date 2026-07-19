using KLS.Common;
using KLS.Contract.Interfaces;
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
    }
}
