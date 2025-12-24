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
        PagingResponse<PayrollList> GetPagedList(PayrollReq payrollReq);

        void InjectEmp(PayrollInjectEmpReq injectEmpReq);

        void Inject(int vendorPaymentId);

        void Delete(int vendorPaymentId);

        ImportPayrollResp Import(IFormFile payrollFile);

        void VoidCheck(int vendorPaymentId);
    }
}
