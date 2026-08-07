using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace KLS.Data.Repositories
{
    public class BankFeedTransactionRepository : KLSRepository<BankFeedTransaction>, IBankFeedTransactionRepository
    {
        public BankFeedTransactionRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public BankFeedTransaction? GetByLongId(long bankFeedTransactionId)
        {
            return DbContext.BankFeedTransactions.FirstOrDefault(c => c.BankFeedTransactionId == bankFeedTransactionId);
        }

        public IQueryable<BankFeedTransactionList> GetPagedList(BankFeedListReq req)
        {
            var param = BuildListParam(req);
            return DbContext.BankFeedTransactionList.FromSqlRaw(
                "[dbo].[BankFeed_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@AccountId,@Status,@AmountDirection,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT",
                param);
        }

        public int CountList(BankFeedListReq req)
        {
            req.IsCount = true;
            var param = BuildListParam(req);
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[BankFeed_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@AccountId,@Status,@AmountDirection,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT",
                param);
            var output = param[11] as SqlParameter;
            return Convert.ToInt32(output!.Value);
        }

        public IQueryable<BankFeedMatchCandidate> GetMatchCandidates(long bankFeedTransactionId)
        {
            var param = new SqlParameter("@BankFeedTransactionId", bankFeedTransactionId);
            return DbContext.BankFeedMatchCandidate.FromSqlRaw(
                "[dbo].[BankFeed_GetMatchTxList] @BankFeedTransactionId", param);
        }

        public IQueryable<BankFeedOpenBill> GetOpenBills(BankFeedOpenBillsReq req)
        {
            var param = BuildOpenBillsParam(req);
            return DbContext.BankFeedOpenBill.FromSqlRaw(
                "[dbo].[BankFeed_GetOpenBills] @BankFeedTransactionId,@PayeeId,@Search,@Pageno,@Pagesize,@IsCount,@TotalCount OUTPUT",
                param);
        }

        public int CountOpenBills(BankFeedOpenBillsReq req)
        {
            req.IsCount = true;
            var param = BuildOpenBillsParam(req);
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[BankFeed_GetOpenBills] @BankFeedTransactionId,@PayeeId,@Search,@Pageno,@Pagesize,@IsCount,@TotalCount OUTPUT",
                param);
            var output = param[6] as SqlParameter;
            return output!.Value == DBNull.Value ? 0 : Convert.ToInt32(output.Value);
        }

        public IQueryable<BankFeedUndepositedPayment> GetUndepositedPayments(BankFeedUndepositedPaymentsReq req)
        {
            var param = BuildUndepositedPaymentsParam(req);
            return DbContext.BankFeedUndepositedPayment.FromSqlRaw(
                "[dbo].[BankFeed_GetUndepositedPayments] @BankFeedTransactionId,@Search,@StartDate,@EndDate,@Pageno,@Pagesize,@IsCount,@TotalCount OUTPUT",
                param);
        }

        public int CountUndepositedPayments(BankFeedUndepositedPaymentsReq req)
        {
            req.IsCount = true;
            var param = BuildUndepositedPaymentsParam(req);
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[BankFeed_GetUndepositedPayments] @BankFeedTransactionId,@Search,@StartDate,@EndDate,@Pageno,@Pagesize,@IsCount,@TotalCount OUTPUT",
                param);
            var output = param[7] as SqlParameter;
            return output!.Value == DBNull.Value ? 0 : Convert.ToInt32(output.Value);
        }

        public int CreateVendorPayment(BankFeedCreateVendorPaymentReq req, string linesJson,
                                       string? resolvingLinesJson, int empId)
        {
            var newPaymentId = new SqlParameter
            {
                ParameterName = "@NewVendorPaymentId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            // Parameters are passed BY NAME, not positionally. The procedure gained
            // @ResolvingLinesJson and @ChargePayeeId in the middle of its signature, and a
            // positional call would have silently shifted every argument after them - the same
            // failure that forced a trailing-only parameter on VendorPayment_Insert. Keep the
            // "@X = @X" form so future parameters cannot repeat it.
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[BankFeed_CreateVendorPayment] " +
                "@BankFeedTransactionId = @BankFeedTransactionId, " +
                "@PayeeId = @PayeeId, " +
                "@PaymentMethod = @PaymentMethod, " +
                "@ReferenceId = @ReferenceId, " +
                "@LinesJson = @LinesJson, " +
                "@DifferenceMemo = @DifferenceMemo, " +
                "@ResolvingLinesJson = @ResolvingLinesJson, " +
                "@ChargePayeeId = @ChargePayeeId, " +
                "@EmpId = @EmpId, " +
                "@NewVendorPaymentId = @NewVendorPaymentId OUTPUT",
                new SqlParameter("@BankFeedTransactionId", req.BankFeedTransactionId),
                new SqlParameter("@PayeeId", req.PayeeId),
                new SqlParameter("@PaymentMethod", (object?)req.PaymentMethod ?? DBNull.Value),
                new SqlParameter("@ReferenceId", (object?)req.ReferenceId ?? DBNull.Value),
                new SqlParameter("@LinesJson", linesJson),
                new SqlParameter("@DifferenceMemo", (object?)req.DifferenceMemo ?? DBNull.Value),
                new SqlParameter("@ResolvingLinesJson", (object?)resolvingLinesJson ?? DBNull.Value),
                new SqlParameter("@ChargePayeeId", (object?)req.ChargePayeeId ?? DBNull.Value),
                new SqlParameter("@EmpId", empId),
                newPaymentId);

            return newPaymentId.Value == DBNull.Value ? 0 : Convert.ToInt32(newPaymentId.Value);
        }

        public IQueryable<BankFeedOpenInvoice> GetOpenInvoices(BankFeedOpenInvoicesReq req)
        {
            var param = BuildOpenInvoicesParam(req);
            return DbContext.BankFeedOpenInvoice.FromSqlRaw(
                "[dbo].[BankFeed_GetOpenInvoices] @BankFeedTransactionId,@PayeeId,@Search,@Pageno,@Pagesize,@IsCount,@TotalCount OUTPUT",
                param);
        }

        public int CountOpenInvoices(BankFeedOpenInvoicesReq req)
        {
            req.IsCount = true;
            var param = BuildOpenInvoicesParam(req);
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[BankFeed_GetOpenInvoices] @BankFeedTransactionId,@PayeeId,@Search,@Pageno,@Pagesize,@IsCount,@TotalCount OUTPUT",
                param);
            var output = param[6] as SqlParameter;
            return output!.Value == DBNull.Value ? 0 : Convert.ToInt32(output.Value);
        }

        public int CreateDeposit(BankFeedCreateDepositReq req, string paymentIdsJson, int empId)
        {
            var newTFId = new SqlParameter
            {
                ParameterName = "@NewTFId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            // Parameters by name, same as CreateVendorPayment: a future parameter added
            // mid-signature must not silently shift the ones after it.
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[BankFeed_CreateDeposit] " +
                "@BankFeedTransactionId = @BankFeedTransactionId, " +
                "@PaymentIdsJson = @PaymentIdsJson, " +
                "@DifferenceKind = @DifferenceKind, " +
                "@DifferenceAccountId = @DifferenceAccountId, " +
                "@DifferenceMemo = @DifferenceMemo, " +
                "@EmpId = @EmpId, " +
                "@NewTFId = @NewTFId OUTPUT",
                new SqlParameter("@BankFeedTransactionId", req.BankFeedTransactionId),
                new SqlParameter("@PaymentIdsJson", paymentIdsJson),
                new SqlParameter("@DifferenceKind", req.DifferenceKind),
                new SqlParameter("@DifferenceAccountId", (object?)req.DifferenceAccountId ?? DBNull.Value),
                new SqlParameter("@DifferenceMemo", (object?)req.DifferenceMemo ?? DBNull.Value),
                new SqlParameter("@EmpId", empId),
                newTFId);

            return newTFId.Value == DBNull.Value ? 0 : Convert.ToInt32(newTFId.Value);
        }

        public int CreateInvoiceDeposit(BankFeedCreateInvoiceDepositReq req, string linesJson, int empId)
        {
            var newPaymentId = new SqlParameter
            {
                ParameterName = "@NewCustomerPaymentId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };
            var newTFId = new SqlParameter
            {
                ParameterName = "@NewTFId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[BankFeed_CreateCustomerPaymentDeposit] " +
                "@BankFeedTransactionId = @BankFeedTransactionId, " +
                "@PayeeId = @PayeeId, " +
                "@PaymentMethod = @PaymentMethod, " +
                "@ReferenceId = @ReferenceId, " +
                "@LinesJson = @LinesJson, " +
                "@DifferenceKind = @DifferenceKind, " +
                "@DifferenceAccountId = @DifferenceAccountId, " +
                "@DifferenceMemo = @DifferenceMemo, " +
                "@EmpId = @EmpId, " +
                "@NewCustomerPaymentId = @NewCustomerPaymentId OUTPUT, " +
                "@NewTFId = @NewTFId OUTPUT",
                new SqlParameter("@BankFeedTransactionId", req.BankFeedTransactionId),
                new SqlParameter("@PayeeId", req.PayeeId),
                new SqlParameter("@PaymentMethod", req.PaymentMethod),
                new SqlParameter("@ReferenceId", (object?)req.ReferenceId ?? DBNull.Value),
                new SqlParameter("@LinesJson", linesJson),
                new SqlParameter("@DifferenceKind", req.DifferenceKind),
                new SqlParameter("@DifferenceAccountId", (object?)req.DifferenceAccountId ?? DBNull.Value),
                new SqlParameter("@DifferenceMemo", (object?)req.DifferenceMemo ?? DBNull.Value),
                new SqlParameter("@EmpId", empId),
                newPaymentId,
                newTFId);

            return newTFId.Value == DBNull.Value ? 0 : Convert.ToInt32(newTFId.Value);
        }

        public void MatchTx(long bankFeedTransactionId, string matchItemsJson, int matchedBy)
        {
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[BankFeed_MatchTx] @BankFeedTransactionId, @MatchItemsJson, @MatchedBy",
                new SqlParameter("@BankFeedTransactionId", bankFeedTransactionId),
                new SqlParameter("@MatchItemsJson", matchItemsJson),
                new SqlParameter("@MatchedBy", matchedBy));
        }

        public void UnMatchTx(long bankFeedTransactionId)
        {
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[BankFeed_UnMatchTx] @BankFeedTransactionId",
                new SqlParameter("@BankFeedTransactionId", bankFeedTransactionId));
        }

        private object[] BuildOpenInvoicesParam(BankFeedOpenInvoicesReq req)
        {
            object[] param = {
                new SqlParameter("@BankFeedTransactionId", req.BankFeedTransactionId),
                new SqlParameter("@PayeeId", req.PayeeId),
                !string.IsNullOrEmpty(req.Search) ? new SqlParameter("@Search", req.Search) : new SqlParameter("@Search", DBNull.Value),
                new SqlParameter("@Pageno", req.Pageno),
                new SqlParameter("@Pagesize", req.Pagesize),
                new SqlParameter("@IsCount", req.IsCount),
                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };
            return param;
        }

        private object[] BuildUndepositedPaymentsParam(BankFeedUndepositedPaymentsReq req)
        {
            object ToDbDate(DateOnly? d) => d.HasValue ? d.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value;

            object[] param = {
                new SqlParameter("@BankFeedTransactionId", req.BankFeedTransactionId),
                !string.IsNullOrEmpty(req.Search) ? new SqlParameter("@Search", req.Search) : new SqlParameter("@Search", DBNull.Value),
                new SqlParameter("@StartDate", ToDbDate(req.StartDate)),
                new SqlParameter("@EndDate", ToDbDate(req.EndDate)),
                new SqlParameter("@Pageno", req.Pageno),
                new SqlParameter("@Pagesize", req.Pagesize),
                new SqlParameter("@IsCount", req.IsCount),
                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };
            return param;
        }

        private object[] BuildOpenBillsParam(BankFeedOpenBillsReq req)
        {
            object[] param = {
                new SqlParameter("@BankFeedTransactionId", req.BankFeedTransactionId),
                new SqlParameter("@PayeeId", req.PayeeId),
                !string.IsNullOrEmpty(req.Search) ? new SqlParameter("@Search", req.Search) : new SqlParameter("@Search", DBNull.Value),
                new SqlParameter("@Pageno", req.Pageno),
                new SqlParameter("@Pagesize", req.Pagesize),
                new SqlParameter("@IsCount", req.IsCount),
                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };
            return param;
        }

        private object[] BuildListParam(BankFeedListReq req)
        {
            object[] param = {
                new SqlParameter("@Pageno", req.Pageno),
                new SqlParameter("@Pagesize", req.Pagesize),
                !string.IsNullOrEmpty(req.Search) ? new SqlParameter("@Search", req.Search) : new SqlParameter("@Search", DBNull.Value),
                req.StartDate.HasValue ? new SqlParameter("@StartDate", req.StartDate) : new SqlParameter("@StartDate", DBNull.Value),
                req.EndDate.HasValue ? new SqlParameter("@EndDate", req.EndDate) : new SqlParameter("@EndDate", DBNull.Value),
                req.AccountId.HasValue ? new SqlParameter("@AccountId", req.AccountId) : new SqlParameter("@AccountId", DBNull.Value),
                !string.IsNullOrEmpty(req.Status) ? new SqlParameter("@Status", req.Status) : new SqlParameter("@Status", DBNull.Value),
                !string.IsNullOrEmpty(req.AmountDirection) ? new SqlParameter("@AmountDirection", req.AmountDirection) : new SqlParameter("@AmountDirection", DBNull.Value),
                !string.IsNullOrEmpty(req.SortField) ? new SqlParameter("@SortField", req.SortField) : new SqlParameter("@SortField", DBNull.Value),
                !string.IsNullOrEmpty(req.SortOrder) ? new SqlParameter("@SortOrder", req.SortOrder) : new SqlParameter("@SortOrder", DBNull.Value),
                new SqlParameter("@IsCount", req.IsCount),
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
