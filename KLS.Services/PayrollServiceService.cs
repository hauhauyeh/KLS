using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PayrollServiceService : BaseService, IPayrollServiceService
    {
        private readonly IDeleteLogService _deleteLogService;

        public PayrollServiceService(IUnitOfWork uow, IDeleteLogService deleteLogService) : base(uow)
        {
            _deleteLogService = deleteLogService;
        }

        public PagingResponse<PayrollServiceDTO> GetAllPayrollService(PayrollServiceReq payrollServiceReq)
        {
            var payrollServicelist = Uow.PayrollServices.GetAllPayrollService(payrollServiceReq);

            var totalRecords = Uow.PayrollServices.CountAllPayrollService(payrollServiceReq);

            return new PagingResponse<PayrollServiceDTO>(totalRecords, payrollServiceReq.Pageno, payrollServiceReq.Pagesize)
            {
                RowData = payrollServicelist,
            };
        }

        public PayrollService GetById(int payrollServiceId)
        {
            return Uow.PayrollServices.GetById(payrollServiceId);
        }

        public PayrollService SavePayrollService(PayrollService service)
        {
            var payrollServiceId = Uow.PayrollServices.SavePayrollService(service);

            return GetById(payrollServiceId);
        }

        public void DeletePayrollService(int payrollServiceId)
        {
            var payrollService = GetById(payrollServiceId);

            if (payrollService != null && !payrollService.IsLocked)
            {
                Uow.PayrollServices.Find(c => c.PayrollServiceId == payrollServiceId).ExecuteDelete();

                string docType = EnumHelper.DocType.PayrollService.ToString();

                _deleteLogService.Add(docType, payrollServiceId);
            }
        }

        public void InjectPayrollService(int payrollServiceId, bool isClone)
        {
            Uow.PayrollServices.InjectPayrollService(payrollServiceId, isClone);
        }

        public void InjectEmployee()
        {
            Uow.PayrollServices.InjectEmployee();
        }
    }
}
