using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class EmployeeAdvancePmtService : BaseService, IEmployeeAdvancePmtService
    {
        private readonly IDeleteLogService _deleteLogService;

        public EmployeeAdvancePmtService(IUnitOfWork uow, IDeleteLogService deleteLogService) : base(uow)
        {
            _deleteLogService = deleteLogService;
        }

        public PagingResponse<EmployeeAdvancePmt> GetAllEmployeeAdvancePmt(EmployeeAdvancePmtReq empAdvanceReq)
        {
            var empAdvanceList = Uow.EmployeeAdvancePmts.GetAllEmployeeAdvancePmt(empAdvanceReq);

            var totalRecords = Uow.EmployeeAdvancePmts.CountAllEmployeeAdvancePmt(empAdvanceReq);

            return new PagingResponse<EmployeeAdvancePmt>(totalRecords, empAdvanceReq.Pageno, empAdvanceReq.Pagesize)
            {
                RowData = empAdvanceList
            };
        }

        public VendorPayment? GetById(int vendorPaymentId)
        {
            return Uow.VendorPayments.GetById(vendorPaymentId);
        }

        public VendorPayment SaveEmployeeAdvancePmt(EmployeeAdvancePmt employeeAdvancePmt)
        {
            var newVendorPaymentId = Uow.EmployeeAdvancePmts.SaveEmployeeAdvancePmt(employeeAdvancePmt);

            return GetById(newVendorPaymentId);
        }

        public void Delete(int vendorPaymentId)
        {
            var vendorPayment = GetById(vendorPaymentId);

            if (vendorPayment != null && !vendorPayment.IsLocked)
            {
                Uow.VendorPayments.RemoveById(vendorPaymentId);
                Uow.Commit();

                string docType = EnumHelper.DocType.LoantoEmployee.ToString();

                _deleteLogService.Add(docType, vendorPaymentId);
            }
        }
    }
}
