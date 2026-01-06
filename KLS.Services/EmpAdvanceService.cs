using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class EmpAdvanceService : BaseService, IEmpAdvanceService
    {
        private readonly IDeleteLogService _deleteLogService;

        public EmpAdvanceService(IUnitOfWork uow, IDeleteLogService deleteLogService) : base(uow)
        {
            _deleteLogService = deleteLogService;
        }

        public PagingResponse<EmpAdvance> GetPagedList(EmpAdvanceReq empAdvanceReq)
        {
            var empAdvanceList = Uow.EmpAdvances.GetPagedList(empAdvanceReq);

            var totalRecords = Uow.EmpAdvances.Count(empAdvanceReq);

            return new PagingResponse<EmpAdvance>(totalRecords, empAdvanceReq.Pageno, empAdvanceReq.Pagesize)
            {
                RowData = empAdvanceList
            };
        }

        public VendorPayment? GetById(int vendorPaymentId)
        {
            return Uow.VendorPayments.GetById(vendorPaymentId);
        }

        public VendorPayment Save(EmpAdvance empAdvance)
        {
            var newVendorPaymentId = Uow.EmpAdvances.Save(empAdvance);

            return GetById(newVendorPaymentId);
        }

        public void Delete(int vendorPaymentId)
        {
            var vendorPayment = GetById(vendorPaymentId);

            if (vendorPayment != null && !vendorPayment.IsLocked)
            {
                Uow.VendorPayments.Find(c => c.VendorPaymentId == vendorPaymentId).ExecuteDelete();

                string docType = EnumHelper.DocType.LoantoEmployee.ToString();

                _deleteLogService.Add(docType, vendorPaymentId);
            }
        }
    }
}
