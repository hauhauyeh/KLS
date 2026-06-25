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
