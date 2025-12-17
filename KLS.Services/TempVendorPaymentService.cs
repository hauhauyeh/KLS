using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
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

        public IEnumerable<TempVendorPayment> Inject(TempVendorPaymentListReq tempReq)
        {
            return Uow.TempVendorPayments.Inject(tempReq);
        }

        public void Update(TempVendorPayment tempVendorPayment)
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
