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
        IQueryable<IncomingPaymentList> GetIncomingPayments(IncomingPaymentListReq incomingPaymentReq);

        int CountAllIncomingPayments(IncomingPaymentListReq incomingPaymentReq);

        int SaveIncomingPayment(IncomingPaymentReq incomingPaymentReq);
    }
}
