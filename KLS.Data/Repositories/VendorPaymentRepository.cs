using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Org.BouncyCastle.Ocsp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class VendorPaymentRepository : KLSRepository<VendorPayment>, IVendorPaymentRepository
    {
        public VendorPaymentRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<VendorPaymentList> GetPagedVendorPayments(VendorPaymentReq vendorPaymentReq)
        {
            var param = BuildVendorPaymentParam(vendorPaymentReq);

            return DbContext.VendorPaymentList.FromSqlRaw("[dbo].[VendorPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@FromAccountId,@PaymentMethod,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountVendorPayments(VendorPaymentReq vendorPaymentReq)
        {
            vendorPaymentReq.IsCount = true;
            var param = BuildVendorPaymentParam(vendorPaymentReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@FromAccountId,@PaymentMethod,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[12] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildVendorPaymentParam(VendorPaymentReq vendorPaymentReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", vendorPaymentReq.Pageno),

                new SqlParameter("@Pagesize", vendorPaymentReq.Pagesize),

                string.IsNullOrEmpty(vendorPaymentReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", vendorPaymentReq.Search),

                vendorPaymentReq.StartDate.HasValue ? new SqlParameter("@StartDate", vendorPaymentReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                vendorPaymentReq.EndDate.HasValue ? new SqlParameter("@EndDate", vendorPaymentReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                vendorPaymentReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", vendorPaymentReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                vendorPaymentReq.FromAccountId.HasValue ? new SqlParameter("@FromAccountId", vendorPaymentReq.FromAccountId) : new SqlParameter("@FromAccountId", DBNull.Value),

                string.IsNullOrEmpty(vendorPaymentReq.PaymentMethod) ? new SqlParameter("@PaymentMethod", DBNull.Value) : new SqlParameter("@PaymentMethod", vendorPaymentReq.PaymentMethod),

                string.IsNullOrEmpty(vendorPaymentReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", vendorPaymentReq.Filterby),

                string.IsNullOrEmpty(vendorPaymentReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", vendorPaymentReq.SortField),

                string.IsNullOrEmpty(vendorPaymentReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", vendorPaymentReq.SortOrder),

                new SqlParameter("@IsCount", vendorPaymentReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }

        public int Save(VendorPayment vendorPayment)
        {
            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", vendorPayment.VendorPaymentId);

            var PayeeIdParam = new SqlParameter("@PayeeId", vendorPayment.PayeeId);

            var PaymentDateParam = vendorPayment.PaymentDate.HasValue ? new SqlParameter("@PaymentDate", vendorPayment.PaymentDate) : new SqlParameter("@PaymentDate", DBNull.Value);

            var PaymentTypeParam = (!string.IsNullOrEmpty(vendorPayment.PaymentType)) ? new SqlParameter("@PaymentType", vendorPayment.PaymentType) : new SqlParameter("@PaymentType", DBNull.Value);

            var PaymentMethodParam = (!string.IsNullOrEmpty(vendorPayment.PaymentMethod)) ? new SqlParameter("@PaymentMethod", vendorPayment.PaymentMethod) : new SqlParameter("@PaymentMethod", DBNull.Value);

            var ReferenceIdParam = (!string.IsNullOrEmpty(vendorPayment.ReferenceId)) ? new SqlParameter("@ReferenceId", vendorPayment.ReferenceId) : new SqlParameter("@ReferenceId", DBNull.Value);

            var FromAccountIdParam = vendorPayment.FromAccountId.HasValue ? new SqlParameter("@FromAccountId", vendorPayment.FromAccountId) : new SqlParameter("@FromAccountId", DBNull.Value);

            var PaymentAmountParam = vendorPayment.PaymentAmount.HasValue ? new SqlParameter("@PaymentAmount", vendorPayment.PaymentAmount) : new SqlParameter("@PaymentAmount", DBNull.Value);

            var NotesParam = (!string.IsNullOrEmpty(vendorPayment.Notes)) ? new SqlParameter("@Notes", vendorPayment.Notes) : new SqlParameter("@Notes", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var NewPaymentId = new SqlParameter()
            {
                ParameterName = "@NewPaymentId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_Insert] @VendorPaymentId,@PayeeId,@PaymentDate,@PaymentType,@PaymentMethod,@ReferenceId,@FromAccountId,@PaymentAmount,@Notes,@EmpId,@NewPaymentId OUTPUT", VendorPaymentIdParam, PayeeIdParam, PaymentDateParam, PaymentTypeParam, PaymentMethodParam, ReferenceIdParam, FromAccountIdParam, PaymentAmountParam, NotesParam, EmpIdParam, NewPaymentId);

            return Convert.ToInt32(NewPaymentId.Value);
        }

        public void VoidCheck(int vendorPaymentId)
        {
            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", vendorPaymentId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_VoidCheck] @VendorPaymentId", VendorPaymentIdParam);
        }

        public void UnVoidCheck(int vendorPaymentId)
        {
            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", vendorPaymentId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_UnVoidCheck] @VendorPaymentId", VendorPaymentIdParam);
        }

        public void Return(VendorPaymentReturnReq checkReq)
        {
            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", checkReq.VendorPaymentId);

            var ReturnTypeParam = (!string.IsNullOrEmpty(checkReq.ReturnType)) ? new SqlParameter("@ReturnType", checkReq.ReturnType) : new SqlParameter("@ReturnType", DBNull.Value);

            var ReturnDateParam = checkReq.ReturnDate.HasValue ? new SqlParameter("@ReturnDate", checkReq.ReturnDate) : new SqlParameter("@ReturnDate", DBNull.Value);

            var FeeAccountIdParam = checkReq.FeeAccountId.HasValue ? new SqlParameter("@FeeAccountId", checkReq.FeeAccountId) : new SqlParameter("@FeeAccountId", DBNull.Value);

            var FeeAmountParam = checkReq.FeeAmount.HasValue ? new SqlParameter("@FeeAmount", checkReq.FeeAmount) : new SqlParameter("@FeeAmount", DBNull.Value);

            var IsRedepositParam = new SqlParameter("@IsRedeposit", checkReq.IsRedeposit);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_ReturnCheck] @VendorPaymentId,@ReturnType,@ReturnDate,@FeeAccountId,@FeeAmount,@IsRedeposit", VendorPaymentIdParam, ReturnTypeParam, ReturnDateParam, FeeAccountIdParam, FeeAmountParam, IsRedepositParam);
        }

        public void DeleteReturn(int vendorPaymentId)
        {
            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", vendorPaymentId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_ReturnDelete] @VendorPaymentId", VendorPaymentIdParam);
        }

        public int SavePayNow(PayNowReq payNowReq)
        {
            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", payNowReq.VendorPaymentId);

            var PayeeIdParam = new SqlParameter("@PayeeId", payNowReq.PayeeId);

            var PaymentDateParam = payNowReq.PaymentDate.HasValue ? new SqlParameter("@PaymentDate", payNowReq.PaymentDate) : new SqlParameter("@PaymentDate", DBNull.Value);

            var PaymentMethodParam = (!string.IsNullOrEmpty(payNowReq.PaymentMethod)) ? new SqlParameter("@PaymentMethod", payNowReq.PaymentMethod) : new SqlParameter("@PaymentMethod", DBNull.Value);

            var FromAccountIdParam = payNowReq.FromAccountId.HasValue ? new SqlParameter("@FromAccountId", payNowReq.FromAccountId) : new SqlParameter("@FromAccountId", DBNull.Value);

            var ReferenceIdParam = (!string.IsNullOrEmpty(payNowReq.ReferenceId)) ? new SqlParameter("@ReferenceId", payNowReq.ReferenceId) : new SqlParameter("@ReferenceId", DBNull.Value);

            var PaymentAmountParam = payNowReq.PaymentAmount.HasValue ? new SqlParameter("@PaymentAmount", payNowReq.PaymentAmount) : new SqlParameter("@PaymentAmount", DBNull.Value);

            var NotesParam = (!string.IsNullOrEmpty(payNowReq.Notes)) ? new SqlParameter("@Notes", payNowReq.Notes) : new SqlParameter("@Notes", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var NewPaymentId = new SqlParameter()
            {
                ParameterName = "@NewPaymentId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_InsertPayNow] @VendorPaymentId,@PayeeId,@PaymentDate,@PaymentMethod,@FromAccountId,@ReferenceId,@PaymentAmount,@Notes,@EmpId,@NewPaymentId OUTPUT", VendorPaymentIdParam, PayeeIdParam, PaymentDateParam, PaymentMethodParam, FromAccountIdParam, ReferenceIdParam, PaymentAmountParam, NotesParam, EmpIdParam, NewPaymentId);

            return Convert.ToInt32(NewPaymentId.Value);
        }

        public int ImportPayNow(ImportPayNow importPayNow)
        {
            var PaymentMethodParam = new SqlParameter("@PaymentMethod", importPayNow.PaymentMethod);

            var FromAccountIdParam = new SqlParameter("@FromAccountId", importPayNow.FromAccountId);

            var FilePathParam = new SqlParameter("@FilePath", importPayNow.FilePath);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var txCount = new SqlParameter()
            {
                ParameterName = "@TxCount",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_Import] @PaymentMethod,@FromAccountId,@FilePath,@EmpId,@TxCount OUTPUT", PaymentMethodParam, FromAccountIdParam, FilePathParam, EmpIdParam, txCount);

            return Convert.ToInt32(txCount.Value);
        }

        public IQueryable<VendorPaymentList> GetByPurchaseId(int purchaseId)
        {
            var PurchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);

            return DbContext.VendorPaymentList.FromSqlRaw("[dbo].[VendorPayment_GetByPurchaseId] @PurchaseId", PurchaseIdParam);
        }


        public void SaveAdvance(VendorPaymentAdvanceReq req)
        {
            var PurchaseIdParam = new SqlParameter("@PurchaseId", req.PurchaseId);

            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", req.VendorPaymentId);

            var PaymentDateParam = req.PaymentDate.HasValue
                ? new SqlParameter("@PaymentDate", req.PaymentDate)
                : new SqlParameter("@PaymentDate", DBNull.Value);

            var PaymentMethodParam = string.IsNullOrWhiteSpace(req.PaymentMethod)
                ? new SqlParameter("@PaymentMethod", DBNull.Value)
                : new SqlParameter("@PaymentMethod", req.PaymentMethod);

            var ReferenceIdParam = string.IsNullOrWhiteSpace(req.ReferenceId)
                ? new SqlParameter("@ReferenceId", DBNull.Value)
                : new SqlParameter("@ReferenceId", req.ReferenceId);

            var FromAccountIdParam = new SqlParameter("@FromAccountId", req.FromAccountId);

            var PaymentAmountParam = new SqlParameter("@PaymentAmount", req.PaymentAmount);

            var NotesParam = string.IsNullOrWhiteSpace(req.Notes)
                ? new SqlParameter("@Notes", DBNull.Value)
                : new SqlParameter("@Notes", req.Notes);

            DbContext.Database.ExecuteSqlRaw("[VendorPayment_InsertAdvance] @PurchaseId,@VendorPaymentId,@PaymentDate,@PaymentMethod,@ReferenceId,@FromAccountId,@PaymentAmount,@Notes",
                PurchaseIdParam, VendorPaymentIdParam, PaymentDateParam, PaymentMethodParam, ReferenceIdParam, FromAccountIdParam, PaymentAmountParam, NotesParam);
        }

        public void ApplyAdvance(int purchaseId)
        {
            var PurchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_ApplyAdvance] @PurchaseId", PurchaseIdParam);
        }

        public void ApplyAdvanceManual(AdvanceApplyReq req)
        {
            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", req.VendorPaymentId);

            var BillsParam = string.IsNullOrWhiteSpace(req.Bills)
                ? new SqlParameter("@Bills", DBNull.Value)
                : new SqlParameter("@Bills", req.Bills);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_ApplyAdvanceManual] @VendorPaymentId,@Bills", VendorPaymentIdParam, BillsParam);
        }

        public void UnapplyAdvance(int vendorPaymentId)
        {
            var VendorPaymentIdParam = new SqlParameter("@vendorPaymentId", vendorPaymentId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_UnapplyAdvance] @VendorPaymentId", VendorPaymentIdParam);
        }

        public IQueryable<VendorAppliedBill> GetAppliedBills(int vendorPaymentId)
        {
            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", vendorPaymentId);

            return DbContext.VendorAppliedBill.FromSqlRaw("[dbo].[VendorPayment_GetAppliedBills] @VendorPaymentId", VendorPaymentIdParam);
        }


        public IQueryable<CheckRegister> GetPagedCheckRegister(CheckRegisterReq checkRegisterReq)
        {
            var param = BuildCheckRegisterParam(checkRegisterReq);

            return DbContext.CheckRegister.FromSqlRaw("[dbo].[CheckRegister_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@FromAccountId,@PaymentMethod,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountCheckRegister(CheckRegisterReq checkRegisterReq)
        {
            checkRegisterReq.IsCount = true;
            var param = BuildCheckRegisterParam(checkRegisterReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[CheckRegister_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@FromAccountId,@PaymentMethod,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[12] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildCheckRegisterParam(CheckRegisterReq checkRegisterReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", checkRegisterReq.Pageno),

                new SqlParameter("@Pagesize", checkRegisterReq.Pagesize),

                string.IsNullOrEmpty(checkRegisterReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", checkRegisterReq.Search),

                checkRegisterReq.StartDate.HasValue ? new SqlParameter("@StartDate", checkRegisterReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                checkRegisterReq.EndDate.HasValue ? new SqlParameter("@EndDate", checkRegisterReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                checkRegisterReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", checkRegisterReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                checkRegisterReq.FromAccountId.HasValue ? new SqlParameter("@FromAccountId", checkRegisterReq.FromAccountId.Value) : new SqlParameter("@FromAccountId", DBNull.Value),

                string.IsNullOrEmpty(checkRegisterReq.PaymentMethod) ? new SqlParameter("@PaymentMethod", DBNull.Value) : new SqlParameter("@PaymentMethod", checkRegisterReq.PaymentMethod),

                string.IsNullOrEmpty(checkRegisterReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", checkRegisterReq.Filterby),

                string.IsNullOrEmpty(checkRegisterReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", checkRegisterReq.SortField),

                string.IsNullOrEmpty(checkRegisterReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", checkRegisterReq.SortOrder),

                new SqlParameter("@IsCount", checkRegisterReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }

        public void UpdateBankDate(CheckRegister checkRegister)
        {
            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", checkRegister.VendorPaymentId);

            var IsLockedParam = new SqlParameter("@IsLocked", checkRegister.IsLocked);

            var BankDateParam = checkRegister.BankDate.HasValue
                ? new SqlParameter("@BankDate", checkRegister.BankDate)
                : new SqlParameter("@BankDate", DBNull.Value);

            var MailDateParam = checkRegister.MailDate.HasValue
                ? new SqlParameter("@MailDate", checkRegister.MailDate)
                : new SqlParameter("@MailDate", DBNull.Value);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_UpdateBankDate] @VendorPaymentId,@IsLocked,@BankDate,@MailDate", VendorPaymentIdParam, IsLockedParam, BankDateParam, MailDateParam);
        }
    }
}
