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
    public class TempPurchaseRepository : KLSRepository<TempPurchase>, ITempPurchaseRepository
    {
        public TempPurchaseRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<TempPurchaseItem>? GetList(TempPurchaseReq tempReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", tempReq.PayeeId);

            var PurchaseIdParam = new SqlParameter("@PurchaseId", tempReq.PurchaseId);

            var SortFieldParam = (!string.IsNullOrEmpty(tempReq.SortField)) ? new SqlParameter("@SortField", tempReq.SortField) : new SqlParameter("@SortField", DBNull.Value);

            var SortOrderParam = (!string.IsNullOrEmpty(tempReq.SortOrder)) ? new SqlParameter("@SortOrder", tempReq.SortOrder) : new SqlParameter("@SortOrder", DBNull.Value);

            var IdParam = tempReq.TempId.HasValue ? new SqlParameter("@Id", tempReq.TempId) : new SqlParameter("@Id", DBNull.Value);

            return DbContext.TempPurchaseItem.FromSqlRaw("[TempPurchase_GetList] @EmpId,@PayeeId,@PurchaseId,@SortField,@SortOrder,@Id", EmpIdParam, PayeeIdParam, PurchaseIdParam, SortFieldParam, SortOrderParam, IdParam);
        }
    }
}
