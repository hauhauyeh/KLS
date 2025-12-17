using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IEmployeeAdvancePmtService
    {
        PagingResponse<EmployeeAdvancePmt> GetAllEmployeeAdvancePmt(EmployeeAdvancePmtReq empAdvanceReq);

        VendorPayment? GetById(int vendorPaymentId);

        VendorPayment SaveEmployeeAdvancePmt(EmployeeAdvancePmt employeeAdvancePmt);

        void Delete(int vendorPaymentId);
    }
}
