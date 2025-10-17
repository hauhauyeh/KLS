using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class IncomingPaymentService : BaseService, IIncomingPaymentService
    {
        public IncomingPaymentService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<IncomingPaymentList> GetIncomingPayment(IncomingPaymentReq incomingPaymentReq)
        {
            var incomingPaymenList = Uow.IncomingPayments.GetIncomingPayments(incomingPaymentReq);

            var totalRecords = Uow.IncomingPayments.CountAllIncomingPayments(incomingPaymentReq);

            return new PagingResponse<IncomingPaymentList>(totalRecords, incomingPaymentReq.Pageno, incomingPaymentReq.Pagesize)
            {
                RowData = incomingPaymenList,
            };
        }
    }
}
