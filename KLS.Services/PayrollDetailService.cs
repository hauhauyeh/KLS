using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Org.BouncyCastle.Ocsp;
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

            var totalRecords = Uow.PayrollDetails.CountAllPayrolls(payrollReq);

            return new PagingResponse<PayrollList>(totalRecords, payrollReq.Pageno, payrollReq.Pagesize)
            {
                RowData = payrolllist,
            };
        }
    }
}
