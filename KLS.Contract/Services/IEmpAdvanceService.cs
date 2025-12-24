using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IEmpAdvanceService
    {
        PagingResponse<EmpAdvance> GetPagedList(EmpAdvanceReq empAdvanceReq);

        VendorPayment? GetById(int vendorPaymentId);

        VendorPayment Save(EmpAdvance empAdvance);

        void Delete(int vendorPaymentId);
    }
}
