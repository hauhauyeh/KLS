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
    public class TempSalesRepository : KLSRepository<TempSales>, ITempSalesRepository
    {
        public TempSalesRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<TempSalesItem>? GetList(TempSalesReq tempReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", tempReq.PayeeId);

            var SalesIdParam = new SqlParameter("@SalesId", tempReq.SalesId);

            var SortFieldParam = (!string.IsNullOrEmpty(tempReq.SortField)) ? new SqlParameter("@SortField", tempReq.SortField) : new SqlParameter("@SortField", DBNull.Value);

            var SortOrderParam = (!string.IsNullOrEmpty(tempReq.SortOrder)) ? new SqlParameter("@SortOrder", tempReq.SortOrder) : new SqlParameter("@SortOrder", DBNull.Value);

            var IdParam = tempReq.TempId.HasValue ? new SqlParameter("@Id", tempReq.TempId) : new SqlParameter("@Id", DBNull.Value);

            return DbContext.TempSalesItem.FromSqlRaw("[TempSales_GetList] @EmpId,@PayeeId,@SalesId,@SortField,@SortOrder,@Id", EmpIdParam, PayeeIdParam, SalesIdParam, SortFieldParam, SortOrderParam, IdParam);
        }

        public IQueryable<ItemSearch> Search(TempSalesReq tempReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", tempReq.PayeeId);

            var SalesIdParam = new SqlParameter("@SalesId", tempReq.SalesId);

            var SearchTermParam = (!string.IsNullOrEmpty(tempReq.SortField)) ? new SqlParameter("@SearchTerm", tempReq.SearchTerm) : new SqlParameter("@SearchTerm", DBNull.Value);

            return DbContext.ItemSearch.FromSqlRaw("[TempSales_SearchByTerm] @EmpId,@PayeeId,@SalesId,@SearchTerm", EmpIdParam, PayeeIdParam, SalesIdParam, SearchTermParam);
        }
    }
}
