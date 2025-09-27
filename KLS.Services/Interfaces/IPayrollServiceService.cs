using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IPayrollServiceService
    {
        PagingResponse<PayrollServiceDTO> GetPayrollService(PayrollServiceReq payrollServiceReq);
    }
}
