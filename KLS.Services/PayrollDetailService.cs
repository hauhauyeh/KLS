using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PayrollDetailService : BaseService, IPayrollDetailService
    {
        public PayrollDetailService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<PayrollList> GetAllPayrolls(PayrollReq payrollReq)
        {
            var payrolllist = Uow.PayrollDetails.GetAllPayrolls(payrollReq);

            var totalRecords = Uow.PayrollDetails.GetAllPayrolls(payrollReq).ToList().Count();

            return new PagingResponse<PayrollList>(totalRecords, payrollReq.Pageno, payrollReq.Pagesize)
            {
                RowData = payrolllist,
            };
        }
    }
}
