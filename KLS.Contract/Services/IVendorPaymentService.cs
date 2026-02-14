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
        PagingResponse<VendorPaymentList> GetPagedVendorPayments(VendorPaymentReq vendorPaymentReq);

        VendorPayment GetById(int vendorPaymentId);

        VendorPayment? Save(VendorPayment vendorPayment);

        void Delete(int vendorPaymentId);

        void VoidCheck(int vendorPaymentId);

        void UnVoidCheck(int vendorPaymentId);

        void Return(VendorPaymentReturnReq checkReq);

        void DeleteReturn(int paymentId);

        List<string> GetReturnTypes();

        VendorPaymentList? SavePayNow(PayNowReq payNowReq);

        int ImportPayNow(ImportPayNow importPayNow);


        PagingResponse<CheckRegister> GetPagedCheckRegister(CheckRegisterReq checkRegisterReq);
    }
}
