using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IPayrollDetailRepository : IRepository<PayrollDetail>
    {
        IQueryable<PayrollList> GetPagedList(PayrollReq payrollReq);

        int Count(PayrollReq payrollReq);

        void InjectEmp(PayrollInjectEmpReq injectEmpReq);

        void Inject(int vendorPaymentId);

        void SavePayroll(Payroll payroll);

        ImportPayrollResp ImportPayroll(string excelfile);

        void VoidCheck(int vendorPaymentId);
    }
}
