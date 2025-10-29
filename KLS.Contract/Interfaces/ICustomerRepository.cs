using KLS.Contract.Interfaces;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ICustomerRepository : IRepository<Customer>
    {
        IQueryable<CustomerList> GetAllCustomers(CustomerListReq customerListReq);

        int CountAllCustomers(CustomerListReq customerListReq);

        IQueryable<PayeeSearch>? SearchCustomer(PayeeSearchReq searchReq);
    }
}
