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
    public class CustomerPaymentService : BaseService, ICustomerPaymentService
    {
        public CustomerPaymentService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<CustomerPaymentList> GetCustomerPayment(CustomerPaymentReq customerPaymentReq)
        {
            var loglist = Uow.CustomerPayments.GetCustomerPayment(customerPaymentReq);

            var totalRecords = Uow.CustomerPayments.CountAllCustomerPayment(customerPaymentReq);

            return new PagingResponse<CustomerPaymentList>(totalRecords, customerPaymentReq.Pageno, customerPaymentReq.Pagesize)
            {
                RowData = loglist,
            };
        }
    }
}
