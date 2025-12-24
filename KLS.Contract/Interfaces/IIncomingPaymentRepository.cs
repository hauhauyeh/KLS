using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IIncomingPaymentRepository : IRepository<CustomerPayment>
    {
        IQueryable<IncomingPaymentList> GetPagedList(IncomingPaymentListReq incomingPaymentReq);

        int Count(IncomingPaymentListReq incomingPaymentReq);

        int Save(IncomingPaymentReq incomingPaymentReq);
    }
}
