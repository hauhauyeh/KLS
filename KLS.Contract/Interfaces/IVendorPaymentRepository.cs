using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IVendorPaymentRepository : IRepository<VendorPayment>
    {
        IQueryable<CheckRegister> GetCheckRegister(CheckRegisterReq checkRegisterReq);

        int CountAllCheckRegister(CheckRegisterReq checkRegisterReq);

        IQueryable<VendorPaymentList> GetVendorPayment(VendorPaymentReq vendorPaymentReq);

        int CountAllVendorPayment(VendorPaymentReq vendorPaymentReq);

        void UnVoidCheck(int vendorPaymentId);

    }
}
