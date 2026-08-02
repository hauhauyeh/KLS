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

        IEnumerable<EmployeeList>? GetActive();

        IEnumerable<EmployeeList>? GetDrivers();

        EmployeeDTO? GetById(int payeeId);

        bool NameExists(EmployeeDTO employeeDTO);

        EmployeeDTO Create(EmployeeDTO employeeDTO);

        EmployeeDTO? Update(EmployeeDTO payee);

        /// <summary>Returns false when the employee does not exist or is a hidden system account.</summary>
        bool Delete(int payeeId);

        IEnumerable<PayeeSearch>? Search(PayeeSearchReq searchReq);
    }
}
