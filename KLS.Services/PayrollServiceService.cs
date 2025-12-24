using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Contract.Services;
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

        public PagingResponse<PayrollServiceDTO> GetPagedList(PayrollServiceReq payrollServiceReq)
        {
            var list = Uow.PayrollServices.GetPagedList(payrollServiceReq);

            var totalRecords = Uow.PayrollServices.Count(payrollServiceReq);

            return new PagingResponse<PayrollServiceDTO>(totalRecords, payrollServiceReq.Pageno, payrollServiceReq.Pagesize)
            {
                RowData = list,
            };
        }

        public PayrollService GetById(int payrollServiceId)
        {
            return Uow.PayrollServices.GetById(payrollServiceId);
        }

        public PayrollService Save(PayrollService service)
        {
            var payrollServiceId = Uow.PayrollServices.Save(service);

            return GetById(payrollServiceId);
        }

        public void Delete(int payrollServiceId)
        {
            var payrollService = GetById(payrollServiceId);

            if (payrollService != null && !payrollService.IsLocked)
            {
                Uow.PayrollServices.Find(c => c.PayrollServiceId == payrollServiceId).ExecuteDelete();

                string docType = EnumHelper.DocType.PayrollService.ToString();

                _deleteLogService.Add(docType, payrollServiceId);
            }
        }

        public void Inject(int payrollServiceId, bool isClone)
        {
            Uow.PayrollServices.Inject(payrollServiceId, isClone);
        }

        public void InjectEmployee()
        {
            Uow.PayrollServices.InjectEmployee();
        }
    }
}
