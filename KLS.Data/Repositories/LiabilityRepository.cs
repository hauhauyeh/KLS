using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class LiabilityRepository : KLSRepository<Liability>, ILiabilityRepository
    {
        public LiabilityRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<LiabilityList>? GetList(PagingRequest request)
        {
            var LiabilityTypeParam = new SqlParameter("@LiabilityType", request.Filterby);

            var SortFieldParam = string.IsNullOrEmpty(request.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", request.SortField);

            var SortOrderParam = string.IsNullOrEmpty(request.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", request.SortOrder);

            return DbContext.LiabilityList.FromSqlRaw("[dbo].[Liability_GetList] @LiabilityType,@SortField,@SortOrder", LiabilityTypeParam, SortFieldParam, SortOrderParam);
        }

        public void InsertOpeningLoan(int payeeId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Liability_InsertOpeningLoan] @PayeeId", PayeeIdParam);
        }

        public IEnumerable<LiabilityTxList> GetTxPagedList(LiabilityTxListReq request)
        {
            var param = BuildPagedList(request);

            return DbContext.LiabilityTxList.FromSqlRaw("[dbo].[Liability_TxList] @Pageno,@Pagesize,@PayeeId,@StartDate,@EndDate,@Search,@IsCount,@TotalCount OUTPUT", param);
        }

        public int TxCount(LiabilityTxListReq request)
        {
            request.IsCount = true;
            var param = BuildPagedList(request);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Liability_TxList] @Pageno,@Pagesize,@PayeeId,@StartDate,@EndDate,@Search,@IsCount,@TotalCount OUTPUT", param);

            var output = param[7] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        public int ImportTax(ImportTaxReq importTaxReq)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", importTaxReq.PayeeId);

            var PaymentMethodParam = new SqlParameter("@PaymentMethod", importTaxReq.PaymentMethod);

            var FromAccountIdParam = new SqlParameter("@FromAccountId", importTaxReq.FromAccountId);

            var FilePathParam = new SqlParameter("@FilePath", importTaxReq.FilePath);

            var txCount = new SqlParameter()
            {
                ParameterName = "@TxCount",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[Liability_TaxImport] @PayeeId,@PaymentMethod,@FromAccountId,@FilePath,@TxCount OUTPUT", PayeeIdParam, PaymentMethodParam, FromAccountIdParam, FilePathParam, txCount);

            return Convert.ToInt32(txCount.Value);
        }

        public int SaveLoanPayment(LiabilityPaymentReq paymentReq)
        {
            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", paymentReq.VendorPaymentId);

            var PayeeIdParam = new SqlParameter("@PayeeId", paymentReq.PayeeId);

            var PaymentDateParam = new SqlParameter("@PaymentDate", paymentReq.PaymentDate);

            var PaymentMethodParam = new SqlParameter("@PaymentMethod", paymentReq.PaymentMethod);

            var ReferenceIdParam = (!string.IsNullOrEmpty(paymentReq.ReferenceId)) ? new SqlParameter("@ReferenceId", paymentReq.ReferenceId) : new SqlParameter("@ReferenceId", DBNull.Value);

            var FromAccountIdParam = new SqlParameter("@FromAccountId", paymentReq.FromAccountId);

            var PaymentAmountParam = paymentReq.PaymentAmount.HasValue ? new SqlParameter("@PaymentAmount", paymentReq.PaymentAmount) : new SqlParameter("@PaymentAmount", DBNull.Value);

            var NotesParam = (!string.IsNullOrEmpty(paymentReq.Notes)) ? new SqlParameter("@Notes", paymentReq.Notes) : new SqlParameter("@Notes", DBNull.Value);

            var PrincipalParam = paymentReq.Amount1.HasValue ? new SqlParameter("@Principal", paymentReq.Amount1) : new SqlParameter("@Principal", DBNull.Value);

            var InterestParam = paymentReq.Amount2.HasValue ? new SqlParameter("@Interest", paymentReq.Amount2) : new SqlParameter("@Interest", DBNull.Value);

            var LateFeeParam = paymentReq.Amount3.HasValue ? new SqlParameter("@LateFee", paymentReq.Amount3) : new SqlParameter("@LateFee", DBNull.Value);

            var newPaymentId = new SqlParameter()
            {
                ParameterName = "@NewPaymentId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[Liability_InsertLoanPayment] @VendorPaymentId,@PayeeId,@PaymentDate,@PaymentMethod,@ReferenceId,@FromAccountId,@PaymentAmount,@Notes,@Principal,@Interest,@LateFee,@NewPaymentId OUTPUT", VendorPaymentIdParam, PayeeIdParam, PaymentDateParam, PaymentMethodParam, ReferenceIdParam, FromAccountIdParam, PaymentAmountParam, NotesParam, PrincipalParam, InterestParam, LateFeeParam, newPaymentId);

            return Convert.ToInt32(newPaymentId.Value);
        }

        public int SaveCCPayment(LiabilityPaymentReq paymentReq)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", paymentReq.PayeeId);

            var PaymentDateParam = new SqlParameter("@PaymentDate", paymentReq.PaymentDate);

            var PaymentMethodParam = new SqlParameter("@PaymentMethod", paymentReq.PaymentMethod);

            var ReferenceIdParam = (!string.IsNullOrEmpty(paymentReq.ReferenceId)) ? new SqlParameter("@ReferenceId", paymentReq.ReferenceId) : new SqlParameter("@ReferenceId", DBNull.Value);

            var FromAccountIdParam = new SqlParameter("@FromAccountId", paymentReq.FromAccountId);

            var PaymentAmountParam = paymentReq.PaymentAmount.HasValue ? new SqlParameter("@PaymentAmount", paymentReq.PaymentAmount) : new SqlParameter("@PaymentAmount", DBNull.Value);

            var NotesParam = (!string.IsNullOrEmpty(paymentReq.Notes)) ? new SqlParameter("@Notes", paymentReq.Notes) : new SqlParameter("@Notes", DBNull.Value);

            var InterestParam = paymentReq.Amount2.HasValue ? new SqlParameter("@Interest", paymentReq.Amount2) : new SqlParameter("@Interest", DBNull.Value);

            var LateFeeParam = paymentReq.Amount3.HasValue ? new SqlParameter("@LateFee", paymentReq.Amount3) : new SqlParameter("@LateFee", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var newPaymentId = new SqlParameter()
            {
                ParameterName = "@NewPaymentId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[Liability_InsertCCPayment] @PayeeId,@PaymentDate,@PaymentMethod,@ReferenceId,@FromAccountId,@PaymentAmount,@Notes,@Interest,@LateFee,@EmpId,@NewPaymentId OUTPUT", PayeeIdParam, PaymentDateParam, PaymentMethodParam, ReferenceIdParam, FromAccountIdParam, PaymentAmountParam, NotesParam, InterestParam, LateFeeParam, EmpIdParam, newPaymentId);

            return Convert.ToInt32(newPaymentId.Value);
        }

        private static object[] BuildPagedList(LiabilityTxListReq request)
        {
            object[] param = {
                new SqlParameter("@Pageno", request.Pageno),

                new SqlParameter("@Pagesize", request.Pagesize),

                request.PayeeId.HasValue ? new SqlParameter("@PayeeId", request.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                request.StartDate.HasValue ? new SqlParameter("@StartDate", request.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                request.EndDate.HasValue ? new SqlParameter("@EndDate", request.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                string.IsNullOrEmpty(request.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", request.Search),

                new SqlParameter("@IsCount", request.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }
    }
}
