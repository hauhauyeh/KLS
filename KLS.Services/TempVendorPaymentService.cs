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
    public class TempVendorPaymentService : BaseService, ITempVendorPaymentService
    {
        public TempVendorPaymentService(IUnitOfWork uow) : base(uow)
        {

        }

        public TempVendorPayment GetById(int tempId)
        {
            return Uow.TempVendorPayments.GetById(tempId);
        }

        public IEnumerable<TempVendorPayment>? Inject(TempPaymentReq tempPaymentReq)
        {
            Uow.TempVendorPayments.Inject(tempPaymentReq);

            return Uow.TempVendorPayments
                .Find(c => c.VendorPaymentId == tempPaymentReq.PaymentId && c.PayeeId == tempPaymentReq.PayeeId && c.EmpId == UserContext.EmpId)
                .Include(c => c.Purchase)
                .OrderBy(c => c.Purchase.ArrivalDate).ThenBy(c => c.TempVPId);
        }

        public void Update(TempVendorPayment tempVendorPayment)
        {
            var tempVendorPmt = GetById(tempVendorPayment.TempVPId);

            if (tempVendorPmt != null)
            {
                tempVendorPmt.IsApplied = tempVendorPayment.IsApplied;
                tempVendorPmt.PaymentApplied = tempVendorPayment.PaymentApplied;
                tempVendorPmt.DiscountApplied = tempVendorPayment.DiscountApplied;

                Uow.TempVendorPayments.Update(tempVendorPmt);
                Uow.Commit();
            }
        }
    }
}
