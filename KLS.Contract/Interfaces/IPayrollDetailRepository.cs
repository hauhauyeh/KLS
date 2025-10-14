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
        IQueryable<PayrollList> GetAllPayrolls(PayrollReq payrollReq);

        int CountAllPayrolls(PayrollReq payrollReq);

        void InjectPayrollDetail(int vendorPaymentId);
    }
}
