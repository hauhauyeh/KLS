using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace KLS.Data.Repositories
{
    public class CRMLeadRepository : KLSRepository<CRMLead>, ICRMLeadRepository
    {
        public CRMLeadRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<CRMLeadList> GetPagedList(CRMLeadListReq req)
        {
            var param = BuildParams(req);
            return DbContext.CRMLeadList.FromSqlRaw(
                "[dbo].[CRMLead_GetAllList] @Pageno,@Pagesize,@Search,@SortField,@SortOrder,@Stage,@SalesRepId,@Id,@IsCount,@TotalCount OUTPUT,@EmpId",
                param);
        }

        public int Count(CRMLeadListReq req)
        {
            req.IsCount = true;
            var param = BuildParams(req);
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[CRMLead_GetAllList] @Pageno,@Pagesize,@Search,@SortField,@SortOrder,@Stage,@SalesRepId,@Id,@IsCount,@TotalCount OUTPUT,@EmpId",
                param);
            var output = param[9] as SqlParameter;
            return System.Convert.ToInt32(output!.Value);
        }

        public IQueryable<CRMPipelineSummary> GetPipelineSummary()
        {
            return DbContext.CRMPipelineSummary.FromSqlRaw("[dbo].[CRMLead_PipelineSummary]");
        }

        public void Convert(int leadId, int payeeId)
        {
            var leadIdParam = new SqlParameter("@LeadId", leadId);
            var payeeIdParam = new SqlParameter("@PayeeId", payeeId);
            DbContext.Database.ExecuteSqlRaw("[dbo].[CRMLead_Convert] @LeadId, @PayeeId", leadIdParam, payeeIdParam);
        }

        private static object[] BuildParams(CRMLeadListReq req)
        {
            object[] param = {
                new SqlParameter("@Pageno", req.Pageno),
                new SqlParameter("@Pagesize", req.Pagesize),
                string.IsNullOrEmpty(req.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", req.Search),
                string.IsNullOrEmpty(req.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", req.SortField),
                string.IsNullOrEmpty(req.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", req.SortOrder),
                string.IsNullOrEmpty(req.Stage) ? new SqlParameter("@Stage", DBNull.Value) : new SqlParameter("@Stage", req.Stage),
                req.SalesRepId.HasValue ? new SqlParameter("@SalesRepId", req.SalesRepId.Value) : new SqlParameter("@SalesRepId", DBNull.Value),
                req.Id.HasValue ? new SqlParameter("@Id", req.Id.Value) : new SqlParameter("@Id", DBNull.Value),
                new SqlParameter("@IsCount", req.IsCount),
                new SqlParameter() { ParameterName = "@TotalCount", Direction = System.Data.ParameterDirection.Output, SqlDbType = System.Data.SqlDbType.Int },
                new SqlParameter("@EmpId", UserContext.EmpId)
            };
            return param;
        }
    }
}
