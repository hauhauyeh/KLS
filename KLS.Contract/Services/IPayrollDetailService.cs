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

        Payroll GetById(int vendorPaymentId);

        PayPeriod? InjectEmp(PayrollInjectEmpReq injectEmpReq);

        void Inject(int vendorPaymentId);

        void SavePayroll(Payroll payroll);

        void Delete(int vendorPaymentId);

        ImportPayrollResp Import(IFormFile payrollFile);

        void VoidCheck(int vendorPaymentId);

        void SendTextStmt(int vendorPaymentId);

        void UpdateReferenceId(PayrollUpdateReq updateReq);
    }
}
