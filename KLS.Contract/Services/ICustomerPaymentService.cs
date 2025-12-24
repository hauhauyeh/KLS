using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ICustomerPaymentService
    {
        PagingResponse<CustomerPaymentList> GetPagedList(CustomerPaymentReq customerPaymentReq);
    }
}
