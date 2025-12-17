using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ICustomerService
    {
        PagingResponse<CustomerList> GetAllCustomers(CustomerListReq customerListReq);

        CustomerDTO? GetById(int payeeId);

        bool CustomerExists(CustomerDTO customerDTO);

        CustomerDTO CreateCustomer(CustomerDTO customerDTO);

        CustomerDTO? UpdateCustomer(CustomerDTO customerDTO);

        void DeleteCustomer(int payeeId);

        ICollection<PayeeSearch>? SearchCustomer(PayeeSearchReq searchReq);
    }
}
