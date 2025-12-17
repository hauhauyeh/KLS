using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempPayrollServiceService
    {
        ICollection<TempPayrollService> GetTempServiceList(int payrollServiceId);

        TempPayrollService Create(TempPayrollService tempService);

        TempPayrollService Update(TempPayrollService tempService);

        void Delete(int tempId);
    }
}
