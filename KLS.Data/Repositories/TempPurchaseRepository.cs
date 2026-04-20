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

        public void Reorder(TempPurchaseReorderReq reorderReq)
        {
            if (reorderReq.Items.Count == 0)
                return;

            var sql = new StringBuilder();
            var parameters = new List<SqlParameter>
            {
                new("@EmpId", UserContext.EmpId),
                new("@PayeeId", reorderReq.PayeeId),
                new("@PurchaseId", reorderReq.PurchaseId)
            };

            sql.AppendLine("UPDATE t");
            sql.AppendLine("SET t.LineId = CASE t.TempPurchaseId");

            for (int i = 0; i < reorderReq.Items.Count; i++)
            {
                var item = reorderReq.Items[i];
                var tempIdParam = $"@TempPurchaseId{i}";
                var lineIdParam = $"@LineId{i}";

                sql.AppendLine($"    WHEN {tempIdParam} THEN {lineIdParam}");
                parameters.Add(new SqlParameter(tempIdParam, item.TempPurchaseId));
                parameters.Add(new SqlParameter(lineIdParam, item.LineId));
            }

            sql.AppendLine("END");
            sql.AppendLine("FROM TempPurchase AS t");
            sql.AppendLine("WHERE t.EmpId = @EmpId");
            sql.AppendLine("  AND t.PayeeId = @PayeeId");
            sql.AppendLine("  AND t.PurchaseId = @PurchaseId");
            sql.Append("  AND t.TempPurchaseId IN (");

            for (int i = 0; i < reorderReq.Items.Count; i++)
            {
                if (i > 0)
                    sql.Append(", ");

                sql.Append($"@TempPurchaseId{i}");
            }

            sql.Append(')');

            DbContext.Database.ExecuteSqlRaw(sql.ToString(), parameters.Cast<object>().ToArray());
        }
    }
}
