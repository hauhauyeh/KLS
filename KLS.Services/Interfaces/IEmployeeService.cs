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
        IEnumerable<Payee> GetAllEmployees();

        Payee? GetEmployeeById(int payeeId);

        bool EmployeeExists(Payee payee);

        Payee CreateEmployee(Payee payee);

        Payee? UpdateEmployee(Payee payee);

        void DeleteEmployee(int payeeId);
    }
}
