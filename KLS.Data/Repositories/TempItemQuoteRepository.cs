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
    public class TempItemQuoteRepository : KLSRepository<TempItemQuote>, ITempItemQuoteRepository
    {
        public TempItemQuoteRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<TempItemQuoteList>? GetList(TempItemQuoteReq tempReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", tempReq.PayeeId);

            var SortFieldParam = (!string.IsNullOrEmpty(tempReq.SortField)) ? new SqlParameter("@SortField", tempReq.SortField) : new SqlParameter("@SortField", DBNull.Value);

            var SortOrderParam = (!string.IsNullOrEmpty(tempReq.SortOrder)) ? new SqlParameter("@SortOrder", tempReq.SortOrder) : new SqlParameter("@SortOrder", DBNull.Value);

            var TempIdParam = tempReq.TempId.HasValue ? new SqlParameter("@TempId", tempReq.TempId) : new SqlParameter("@TempId", DBNull.Value);

            return DbContext.TempItemQuoteList.FromSqlRaw("[TempItemQuote_GetList] @EmpId,@PayeeId,@SortField,@SortOrder,@TempId", EmpIdParam, PayeeIdParam, SortFieldParam, SortOrderParam, TempIdParam);
        }
    }
}
