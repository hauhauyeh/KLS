using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempCustomerPaymentService : BaseService, ITempCustomerPaymentService
    {
        public TempCustomerPaymentService(IUnitOfWork uow) : base(uow)
        {
        }

        public TempCustomerPayment GetById(int tempId)
        {
            return Uow.TempCustomerPayments.GetById(tempId);
        }

        public IEnumerable<TempCustomerPaymentList>? Inject(TempPaymentReq tempPaymentReq)
        {
            return Uow.TempCustomerPayments.Inject(tempPaymentReq);
        }

        public void Update(TempCustomerPayment tempCustomerPayment)
        {
            var tempCustomerPmt = GetById(tempCustomerPayment.TempCPId);

            if (tempCustomerPmt != null)
            {
                tempCustomerPmt.IsApplied = tempCustomerPayment.IsApplied;
                tempCustomerPmt.PaymentApplied = tempCustomerPayment.PaymentApplied;
                tempCustomerPmt.DiscountApplied = tempCustomerPayment.DiscountApplied;

                Uow.TempCustomerPayments.Update(tempCustomerPmt);
                Uow.Commit();
            }
        }

        public void Clear(TempPaymentReq tempPaymentReq)
        {
            Uow.TempCustomerPayments.Find(c => c.EmpId == UserContext.EmpId && c.PayeeId == tempPaymentReq.PayeeId).ExecuteDelete();
        }
    }
}
