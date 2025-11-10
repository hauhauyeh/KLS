using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Org.BouncyCastle.Ocsp;
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

        public TempVendorPayment? GetById(int tempVPId)
        {
            return Uow.TempVendorPayments.GetById(tempVPId);
        }

        public IQueryable<TempVendorPayment> InjectTempVendorPayment(TempVendorPaymentListReq tempVendorPaymentListReq)
        {
            return Uow.TempVendorPayments.InjectTempVendorPayment(tempVendorPaymentListReq);
        }

        public void UpdateTempVendorPayment(TempVendorPayment tempVendorPayment)
        {
            var tempVendorPmt = Uow.TempVendorPayments.GetById(tempVendorPayment.TempVPId);

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
