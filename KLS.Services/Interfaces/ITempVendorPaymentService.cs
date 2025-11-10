using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface ITempVendorPaymentService
    {
        TempVendorPayment? GetById(int tempVPId);

        IQueryable<TempVendorPayment> InjectTempVendorPayment(TempVendorPaymentListReq tempVendorPaymentListReq);

        void UpdateTempVendorPayment(TempVendorPayment tempVendorPayment);
    }
}
