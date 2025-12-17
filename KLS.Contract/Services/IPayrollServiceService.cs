using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IPayrollServiceService
    {
        PagingResponse<PayrollServiceDTO> GetAllPayrollService(PayrollServiceReq payrollServiceReq);

        PayrollService GetById(int payrollServiceId);

        PayrollService SavePayrollService(PayrollService payrollService);

        void DeletePayrollService(int payrollId);

        void InjectPayrollService(int payrollServiceId, bool isClone);

        void InjectEmployee();
    }
}
