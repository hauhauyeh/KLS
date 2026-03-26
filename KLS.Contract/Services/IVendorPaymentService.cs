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


        void SaveAdvance(VendorPaymentAdvanceReq req);

        IEnumerable<VendorPaymentList>? GetAdvances(int purchaseId);

        VendorPaymentList? ApplyAdvance(AdvanceApplyReq req);

        VendorPaymentList? UnapplyAdvance(int vendorPaymentId);

        IEnumerable<VendorAppliedBill>? GetAppliedBills(int vendorPaymentId);


        PagingResponse<CheckRegister> GetPagedCheckRegister(CheckRegisterReq checkRegisterReq);

        void UpdateBankDate(CheckRegister checkRegister);
    }
}
