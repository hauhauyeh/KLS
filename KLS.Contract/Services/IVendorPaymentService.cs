using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IVendorPaymentService
    {
        PagingResponse<VendorPaymentList> GetAllVendorPayments(VendorPaymentReq vendorPaymentReq);

        VendorPayment GetById(int vendorPaymentId);

        VendorPayment? SaveVendorPayment(VendorPayment vendorPayment);

        void DeleteVendorPayment(int vendorPaymentId);

        void VoidCheck(int vendorPaymentId);

        void UnVoidCheck(int vendorPaymentId);

        void VendorPaymentReturn(VendorPaymentReturnReq checkReq);

        List<string> GetReturnTypes();

        VendorPaymentList? SavePayNowPayment(PayNowReq payNowReq);

        int ImportPayNow(ImportPayNow importPayNow);


        PagingResponse<CheckRegister> GetAllCheckRegister(CheckRegisterReq checkRegisterReq);
    }
}
