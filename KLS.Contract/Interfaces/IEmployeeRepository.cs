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
        IQueryable<EmployeeList> GetPagedList(EmpReq empReq);

        IQueryable<PayeeSearch>? Search(PayeeSearchReq searchReq);
    }
}
