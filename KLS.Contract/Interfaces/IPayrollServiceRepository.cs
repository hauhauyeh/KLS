using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IPayrollServiceRepository : IRepository<PayrollService>
    {
        IQueryable<PayrollServiceDTO> GetPagedList(PayrollServiceReq payrollServiceReq);

        int Count(PayrollServiceReq payrollServiceReq);


        int Save(PayrollService service);

        void Inject(int payrollServiceId, bool isClone);

        void InjectEmployee();
    }
}
