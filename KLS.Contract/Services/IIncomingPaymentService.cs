using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IIncomingPaymentService
    {
        PagingResponse<IncomingPaymentList> GetIncomingPayment(IncomingPaymentListReq incomingPaymentReq);

        CustomerPayment GetById(int customerPaymentId);

        CustomerPayment SaveIncomingPayment(IncomingPaymentReq incomingPaymentReq);

        void DeleteIncomingPayment(int customerPaymentId);
    }
}