using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace KLS.Data.Repositories
{
    public class TempSalesQuoteRepository : KLSRepository<TempSalesQuote>, ITempSalesQuoteRepository
    {
        public TempSalesQuoteRepository(KLSDBContext dbContext) : base(dbContext) { }

        public IQueryable<TempSalesQuoteItem>? GetList(TempSalesQuoteReq req)
        {
            return DbContext.TempSalesQuoteItem.FromSqlRaw(
                "[TempSalesQuote_GetList] @EmpId,@PayeeId,@SalesQuoteId,@SortField,@SortOrder,@Id",
                new SqlParameter("@EmpId", UserContext.EmpId),
                new SqlParameter("@PayeeId", req.PayeeId),
                new SqlParameter("@SalesQuoteId", req.SalesQuoteId),
                string.IsNullOrEmpty(req.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", req.SortField),
                string.IsNullOrEmpty(req.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", req.SortOrder),
                req.TempId.HasValue ? new SqlParameter("@Id", req.TempId) : new SqlParameter("@Id", DBNull.Value)
            ).AsNoTracking();
        }

        public IQueryable<ItemSearch> Search(TempSalesQuoteReq req)
        {
            return DbContext.ItemSearch.FromSqlRaw(
                "[TempSales_SearchByTerm] @EmpId,@PayeeId,@SalesId,@SearchTerm",
                new SqlParameter("@EmpId", UserContext.EmpId),
                new SqlParameter("@PayeeId", req.PayeeId),
                new SqlParameter("@SalesId", req.SalesQuoteId),
                string.IsNullOrEmpty(req.SearchTerm) ? new SqlParameter("@SearchTerm", DBNull.Value) : new SqlParameter("@SearchTerm", req.SearchTerm)
            );
        }

        public TempSalesQuoteItem? AddLine(SalesQuoteAddLineRequest req)
        {
            return DbContext.TempSalesQuoteItem.FromSqlRaw(
                "[TempSalesQuote_AddLine] @PayeeId,@SalesQuoteId,@EmpId,@ItemId,@ItemCode,@Qty,@UnitPrice,@Unit,@Notes",
                new SqlParameter("@PayeeId", req.PayeeId),
                new SqlParameter("@SalesQuoteId", req.SalesQuoteId),
                new SqlParameter("@EmpId", UserContext.EmpId),
                req.ItemId.HasValue ? new SqlParameter("@ItemId", req.ItemId.Value) : new SqlParameter("@ItemId", DBNull.Value),
                !string.IsNullOrEmpty(req.ItemCode) ? new SqlParameter("@ItemCode", req.ItemCode) : new SqlParameter("@ItemCode", DBNull.Value),
                new SqlParameter("@Qty", req.Qty),
                req.UnitPrice.HasValue ? new SqlParameter("@UnitPrice", req.UnitPrice.Value) : new SqlParameter("@UnitPrice", DBNull.Value),
                !string.IsNullOrEmpty(req.Unit) ? new SqlParameter("@Unit", req.Unit) : new SqlParameter("@Unit", DBNull.Value),
                !string.IsNullOrEmpty(req.Notes) ? new SqlParameter("@Notes", req.Notes) : new SqlParameter("@Notes", DBNull.Value)
            ).AsEnumerable().FirstOrDefault();
        }
    }
}
