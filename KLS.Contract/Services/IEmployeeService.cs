using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IEmployeeService
    {
        IEnumerable<EmployeeList> GetPagedList(EmpReq empReq);

        ICollection<EmployeeList> GetActive();

        EmployeeDTO? GetById(int payeeId);

        bool NameExists(EmployeeDTO employeeDTO);

        EmployeeDTO Create(EmployeeDTO employeeDTO);

        EmployeeDTO? Update(EmployeeDTO payee);

        void Delete(int payeeId);

        IEnumerable<PayeeSearch>? Search(PayeeSearchReq searchReq);
    }
}
