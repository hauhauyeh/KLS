using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ITempCustomerPaymentRepository : IRepository<TempCustomerPayment>
    {
        IQueryable<TempCustomerPaymentList>? GetList(TempPaymentReq tempPaymentReq);

        void Inject(TempPaymentReq tempPaymentReq);

        int InsertInvoice(TempPaymentReq tempPaymentReq);
    }
}
