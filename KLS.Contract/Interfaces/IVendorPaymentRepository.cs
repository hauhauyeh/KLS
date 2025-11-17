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
        IQueryable<CheckRegister> GetAllCheckRegister(CheckRegisterReq checkRegisterReq);

        int CountAllCheckRegister(CheckRegisterReq checkRegisterReq);

        IQueryable<VendorPaymentList> GetAllVendorPayments(VendorPaymentReq vendorPaymentReq);

        int CountAllVendorPayments(VendorPaymentReq vendorPaymentReq);

        void VoidCheck(int vendorPaymentId);

        void UnVoidCheck(int vendorPaymentId);

        void VendorPaymentReturn(VendorPaymentReturnReq checkReq);

        void DeleteReturn(int vendorPaymentId);

        int SavePayNowPayment(PayNowReq payNowReq);
    }
}
