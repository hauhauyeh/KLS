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
        PagingResponse<CustomerList> GetPagedList(CustomerListReq customerListReq);

        CustomerDTO? GetById(int payeeId);

        bool NameExists(CustomerDTO customerDTO);

        CustomerDTO Create(CustomerDTO customerDTO);

        CustomerDTO? Update(CustomerDTO customerDTO);

        void Delete(int payeeId);

        ICollection<PayeeSearch>? Search(PayeeSearchReq searchReq);
    }
}
