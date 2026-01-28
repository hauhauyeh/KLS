using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempCustomerPaymentService
    {
        IEnumerable<TempCustomerPaymentList>? Inject(TempPaymentReq tempPaymentReq);

        void Update(TempCustomerPayment tempCustomerPayment);

        void Clear(TempPaymentReq tempPaymentReq);
    }
}
