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
        IEnumerable<TempCustomerPaymentList>? GetList(TempPaymentReq tempPaymentReq);

        IEnumerable<TempCustomerPaymentList>? Inject(TempPaymentReq tempPaymentReq);

        TempCustomerPaymentList Create(TempPaymentReq tempPaymentReq);

        TempCustomerPaymentList Update(TempCustomerPayment tempCustomerPayment);

        void Clear(int payeeId);

        void Delete(int tempId);
    }
}
