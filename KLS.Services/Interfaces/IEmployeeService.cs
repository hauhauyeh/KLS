using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IEmployeeService
    {
        IEnumerable<EmployeeList> GetAllEmployees(EmpReq empReq);

        ICollection<EmployeeList> GetActiveEmployees();

        EmployeeDTO? GetById(int payeeId);

        bool EmployeeExists(EmployeeDTO employeeDTO);

        EmployeeDTO CreateEmployee(EmployeeDTO employeeDTO);

        EmployeeDTO? UpdateEmployee(EmployeeDTO payee);

        void DeleteEmployee(int payeeId);

        IEnumerable<PayeeSearch>? SearchEmployee(PayeeSearchReq searchReq);
    }
}
