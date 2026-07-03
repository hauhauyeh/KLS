using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace KLS.Data.Repositories
{
    public class CRMActivityRepository : KLSRepository<CRMActivity>, ICRMActivityRepository
    {
        public CRMActivityRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<CRMActivityList> GetByEntity(int? payeeId, int? leadId, int pageNo, int pageSize)
        {
            var param = new object[]
            {
                payeeId.HasValue ? new SqlParameter("@PayeeId", payeeId.Value) : new SqlParameter("@PayeeId", DBNull.Value),
                leadId.HasValue ? new SqlParameter("@LeadId", leadId.Value) : new SqlParameter("@LeadId", DBNull.Value),
                new SqlParameter("@Pageno", pageNo),
                new SqlParameter("@Pagesize", pageSize)
            };

            return DbContext.CRMActivityList.FromSqlRaw(
                "[dbo].[CRMActivity_GetByEntity] @PayeeId,@LeadId,@Pageno,@Pagesize",
                param);
        }
    }
}
