using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IEmployeeRepository : IRepository<Employee>
    {
        IQueryable<EmployeeList> GetAllEmployees(EmpReq empReq);

        IQueryable<PayeeSearch>? SearchEmployee(PayeeSearchReq searchReq);
    }
}
