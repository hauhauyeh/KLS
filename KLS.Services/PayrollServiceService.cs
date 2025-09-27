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
    public class PayrollServiceService : BaseService, IPayrollServiceService
    {
        public PayrollServiceService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<PayrollServiceDTO> GetPayrollService(PayrollServiceReq payrollServiceReq)
        {
            var payrollServicelist = Uow.PayrollServices.GetPayrollService(payrollServiceReq);

            var totalRecords = Uow.PayrollServices.GetPayrollService(payrollServiceReq).ToList().Count();

            return new PagingResponse<PayrollServiceDTO>(totalRecords, payrollServiceReq.Pageno, payrollServiceReq.Pagesize)
            {
                RowData = payrollServicelist,
            };
        }
    }
}
