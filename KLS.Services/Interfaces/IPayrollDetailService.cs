using KLS.Models;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IPayrollDetailService
    {
        PagingResponse<PayrollList> GetAllPayrolls(PayrollReq payrollDetailReq);

        void InjectPayrollDetail(int payrollServiceId);

        int Import(IFormFile PayrollFile);
    }
}
