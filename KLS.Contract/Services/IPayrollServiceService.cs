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
        PagingResponse<PayrollServiceDTO> GetPagedList(PayrollServiceReq payrollServiceReq);

        PayrollService GetById(int payrollServiceId);

        PayrollService Save(PayrollService payrollService);

        void Delete(int payrollId);

        void Inject(int payrollServiceId, bool isClone);

        void InjectEmployee();
    }
}
