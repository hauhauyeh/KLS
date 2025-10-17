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
    public class EmployeeAdvancePmtService : BaseService, IEmployeeAdvancePmtService
    {
        public EmployeeAdvancePmtService(IUnitOfWork uow) : base(uow)
        {

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
            }
        }
    }
}
