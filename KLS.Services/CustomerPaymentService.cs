using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
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

        public PagingResponse<CustomerPaymentList> GetPagedList(CustomerPaymentReq customerPaymentReq)
        {
            var list = Uow.CustomerPayments.GetPagedList(customerPaymentReq);

            var totalRecords = Uow.CustomerPayments.Count(customerPaymentReq);

            return new PagingResponse<CustomerPaymentList>(totalRecords, customerPaymentReq.Pageno, customerPaymentReq.Pagesize)
            {
                RowData = list,
            };
        }
    }
}
