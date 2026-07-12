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
        IQueryable<VendorPaymentList> GetPagedVendorPayments(VendorPaymentReq vendorPaymentReq);

        int CountVendorPayments(VendorPaymentReq vendorPaymentReq);

        int Save(VendorPayment vendorPayment);

        void VoidCheck(int vendorPaymentId);

        void UnVoidCheck(int vendorPaymentId);

        void Return(VendorPaymentReturnReq checkReq);

        void DeleteReturn(int vendorPaymentId);

        int SavePayNow(PayNowReq payNowReq);

        List<ImportPayNowExcelRow> ImportPayNowPreview(string filePath);

        int ImportPayNow(ImportPayNow importPayNow);

        IQueryable<VendorPaymentList> GetByPurchaseId(int purchaseId);

        void SaveAdvance(VendorPaymentAdvanceReq req);

        void ApplyAdvance(int purchaseId);

        void ApplyAdvanceManual(AdvanceApplyReq req);

        void UnapplyAdvance(int vendorPaymentId);

        IQueryable<VendorAppliedBill> GetAppliedBills(int vendorPaymentId);

        IQueryable<VendorPaymentOpenAdvance> GetOpenAdvances(int payeeId);


        IQueryable<CheckRegister> GetPagedCheckRegister(CheckRegisterReq checkRegisterReq);

        int CountCheckRegister(CheckRegisterReq checkRegisterReq);

        void UpdateBankDate(CheckRegister checkRegister);
    }
}
