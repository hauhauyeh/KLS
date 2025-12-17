using KLS.Models;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IPayrollDetailService
    {
        PagingResponse<PayrollList> GetAllPayrolls(PayrollReq payrollDetailReq);

        void InjectPayrollEmp(PayrollInjectEmpReq injectEmpReq);

        void InjectPayroll(int vendorPaymentId);

        void DeletePayroll(int vendorPaymentId);

        ImportPayrollResp Import(IFormFile PayrollFile);

        void VoidCheck(int vendorPaymentId);
    }
}
