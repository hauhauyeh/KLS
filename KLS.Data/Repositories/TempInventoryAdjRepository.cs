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
    public class TempInventoryAdjRepository : KLSRepository<TempInventoryAdj>, ITempInventoryAdjRepository
    {
        public TempInventoryAdjRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<TempInventoryItem>? GetTempAdjItems(TempInventoryReq tempReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var AdjIdParam = new SqlParameter("@AdjId", tempReq.AdjId);

            var SortFieldParam = (!string.IsNullOrEmpty(tempReq.SortField)) ? new SqlParameter("@SortField", tempReq.SortField) : new SqlParameter("@SortField", DBNull.Value);

            var SortOrderParam = (!string.IsNullOrEmpty(tempReq.SortOrder)) ? new SqlParameter("@SortOrder", tempReq.SortOrder) : new SqlParameter("@SortOrder", DBNull.Value);

            return DbContext.TempInventoryItem.FromSqlRaw("[TempInventoryAdj_GetList] @EmpId,@AdjId,@SortField,@SortOrder", EmpIdParam, AdjIdParam, SortFieldParam, SortOrderParam);
        }
    }
}
