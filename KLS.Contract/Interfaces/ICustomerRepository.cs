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
        IQueryable<CustomerList> GetPagedList(CustomerListReq customerListReq);

        int Count(CustomerListReq customerListReq);

        IQueryable<PayeeSearch>? Search(PayeeSearchReq searchReq);

        IQueryable<PayeeExport> Export();

        DateOnly GetNextShipDate(int payeeId);
    }
}
