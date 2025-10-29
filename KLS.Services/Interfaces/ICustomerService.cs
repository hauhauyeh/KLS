using KLS.Contract.Interfaces;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface ICustomerService
    {
        //IEnumerable<Payee> GetAllCustomers();

        PagingResponse<CustomerList> GetAllCustomers(CustomerListReq customerListReq);


        Payee? GetById(int payeeId);

        bool CustomerExists(CustomerDTO customerDTO);

        CustomerDTO CreateCustomer(CustomerDTO customerDTO);

        CustomerDTO? UpdateCustomer(CustomerDTO customerDTO);

        void DeleteCustomer(int payeeId);
    }
}
