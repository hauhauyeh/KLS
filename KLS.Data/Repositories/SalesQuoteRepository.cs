using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;

namespace KLS.Data.Repositories
{
    public class SalesQuoteRepository : KLSRepository<SalesQuote>, ISalesQuoteRepository
    {
        public SalesQuoteRepository(KLSDBContext dbContext) : base(dbContext) { }

        public IQueryable<SalesQuoteList> GetPagedList(SalesQuoteListReq req)
        {
            var param = BuildPagedListParam(req);

            return DbContext.SalesQuoteList.FromSqlRaw("[dbo].[SalesQuote_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@PayeeId,@EmpId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(SalesQuoteListReq req)
        {
            req.IsCount = true;
            var param = BuildPagedListParam(req);

            DbContext.Database.ExecuteSqlRaw("[dbo].[SalesQuote_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@PayeeId,@EmpId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[11] as SqlParameter;
            return Convert.ToInt32(output!.Value);
        }

        public int Insert(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes, int statusId, string? salesQuoteType)
        {
            var newIdParam = new SqlParameter("@NewSalesQuoteId", System.Data.SqlDbType.Int)
            {
                Direction = System.Data.ParameterDirection.Output
            };

            DbContext.Database.ExecuteSqlRaw(
                "EXEC [SalesQuote_Insert] @SalesQuoteId,@PayeeId,@EmpId,@ExpiryDate,@Notes,@StatusId,@NewSalesQuoteId OUTPUT,@SalesQuoteType",
                new SqlParameter("@SalesQuoteId", salesQuoteId),
                new SqlParameter("@PayeeId", payeeId),
                new SqlParameter("@EmpId", UserContext.EmpId),
                expiryDate.HasValue ? new SqlParameter("@ExpiryDate", expiryDate.Value) : new SqlParameter("@ExpiryDate", DBNull.Value),
                string.IsNullOrEmpty(notes) ? new SqlParameter("@Notes", DBNull.Value) : new SqlParameter("@Notes", notes),
                new SqlParameter("@StatusId", statusId),
                newIdParam,
                string.IsNullOrEmpty(salesQuoteType) ? new SqlParameter("@SalesQuoteType", DBNull.Value) : new SqlParameter("@SalesQuoteType", salesQuoteType)
            );

            return Convert.ToInt32(newIdParam.Value);
        }

        public int Update(int salesQuoteId, int payeeId, DateOnly? expiryDate, string? notes, string? salesQuoteType)
        {
            DbContext.Database.ExecuteSqlRaw(
                "EXEC [SalesQuote_Update] @SalesQuoteId,@EmpId,@PayeeId,@ExpiryDate,@Notes,@SalesQuoteType",
                new SqlParameter("@SalesQuoteId", salesQuoteId),
                new SqlParameter("@EmpId", UserContext.EmpId),
                new SqlParameter("@PayeeId", payeeId),
                expiryDate.HasValue ? new SqlParameter("@ExpiryDate", expiryDate.Value) : new SqlParameter("@ExpiryDate", DBNull.Value),
                string.IsNullOrEmpty(notes) ? new SqlParameter("@Notes", DBNull.Value) : new SqlParameter("@Notes", notes),
                string.IsNullOrEmpty(salesQuoteType) ? new SqlParameter("@SalesQuoteType", DBNull.Value) : new SqlParameter("@SalesQuoteType", salesQuoteType)
            );

            return salesQuoteId;
        }

        public void Inject(int salesQuoteId)
        {
            DbContext.Database.ExecuteSqlRaw(
                "EXEC [SalesQuote_Inject] @EmpId,@SalesQuoteId",
                new SqlParameter("@EmpId", UserContext.EmpId),
                new SqlParameter("@SalesQuoteId", salesQuoteId)
            );
        }

        public IEnumerable<SalesQuoteDetailList> GetDetails(int salesQuoteId)
        {
            var idParam = new SqlParameter("@SalesQuoteId", salesQuoteId);

            return DbContext.SalesQuoteDetailList
                .FromSqlRaw("[SalesQuote_GetDetail] @SalesQuoteId", idParam)
                .AsNoTracking()
                .ToList();
        }

        public void Delete(int salesQuoteId)
        {
            DbContext.Database.ExecuteSqlRaw(
                "EXEC [SalesQuote_Delete] @SalesQuoteId",
                new SqlParameter("@SalesQuoteId", salesQuoteId)
            );
        }

        public void UpdateStatus(int salesQuoteId, int statusId)
        {
            DbContext.Database.ExecuteSqlRaw(
                "EXEC [SalesQuote_UpdateStatus] @SalesQuoteId,@StatusId,@EmpId",
                new SqlParameter("@SalesQuoteId", salesQuoteId),
                new SqlParameter("@StatusId", statusId),
                new SqlParameter("@EmpId", UserContext.EmpId)
            );
        }

        public SalesQuoteConvertResult ConvertToSales(int salesQuoteId)
        {
            var newSalesIdParam = new SqlParameter("@NewSalesId", System.Data.SqlDbType.Int)
            {
                Direction = System.Data.ParameterDirection.Output
            };
            var newSalesNumberParam = new SqlParameter("@NewSalesNumber", System.Data.SqlDbType.Int)
            {
                Direction = System.Data.ParameterDirection.Output
            };

            DbContext.Database.ExecuteSqlRaw(
                "EXEC [SalesQuote_ConvertToSales] @SalesQuoteId,@EmpId,@NewSalesId OUTPUT,@NewSalesNumber OUTPUT",
                new SqlParameter("@SalesQuoteId", salesQuoteId),
                new SqlParameter("@EmpId", UserContext.EmpId),
                newSalesIdParam,
                newSalesNumberParam
            );

            return new SalesQuoteConvertResult
            {
                SalesId = newSalesIdParam.Value == DBNull.Value ? 0 : Convert.ToInt32(newSalesIdParam.Value),
                SalesNumber = newSalesNumberParam.Value == DBNull.Value ? 0 : Convert.ToInt32(newSalesNumberParam.Value)
            };
        }

        private static object[] BuildPagedListParam(SalesQuoteListReq req)
        {
            object[] param = {
                new SqlParameter("@Pageno", req.Pageno),

                new SqlParameter("@Pagesize", req.Pagesize),

                string.IsNullOrEmpty(req.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", req.Search),

                req.StartDate.HasValue ? new SqlParameter("@StartDate", req.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                req.EndDate.HasValue ? new SqlParameter("@EndDate", req.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                string.IsNullOrEmpty(req.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", req.Filterby),

                req.PayeeId.HasValue ? new SqlParameter("@PayeeId", req.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                new SqlParameter("@EmpId", UserContext.EmpId),

                string.IsNullOrEmpty(req.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", req.SortField),

                string.IsNullOrEmpty(req.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", req.SortOrder),

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
