using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ITempVendorPaymentRepository : IRepository<TempVendorPayment>
    {
        void Inject(TempPaymentReq tempPaymentReq);

        void Clear(int payeeId);
    }
}
