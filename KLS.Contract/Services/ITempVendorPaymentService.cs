using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempVendorPaymentService
    {
        IEnumerable<TempVendorPayment>? Inject(TempPaymentReq tempPaymentReq);

        void Update(TempVendorPayment tempVendorPayment);
    }
}
