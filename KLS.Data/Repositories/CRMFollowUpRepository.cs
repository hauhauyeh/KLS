using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace KLS.Data.Repositories
{
    public class CRMFollowUpRepository : KLSRepository<CRMFollowUp>, ICRMFollowUpRepository
    {
        public CRMFollowUpRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<CRMFollowUpList> GetPagedList(CRMFollowUpListReq req)
        {
            var param = BuildParams(req);
            return DbContext.CRMFollowUpList.FromSqlRaw(
                "[dbo].[CRMFollowUp_GetAllList] @Pageno,@Pagesize,@Search,@SortField,@SortOrder,@AssignedTo,@Status,@Priority,@StartDate,@EndDate,@IsCount,@TotalCount OUTPUT,@EmpId",
                param);
        }

        public int Count(CRMFollowUpListReq req)
        {
            req.IsCount = true;
            var param = BuildParams(req);
            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[CRMFollowUp_GetAllList] @Pageno,@Pagesize,@Search,@SortField,@SortOrder,@AssignedTo,@Status,@Priority,@StartDate,@EndDate,@IsCount,@TotalCount OUTPUT,@EmpId",
                param);
            var output = param[11] as SqlParameter;
            return Convert.ToInt32(output!.Value);
        }

        public IQueryable<CRMFollowUpList> GetByEntity(int? payeeId, int? leadId, int pageNo, int pageSize)
        {
            object[] param = {
                payeeId.HasValue ? new SqlParameter("@PayeeId", payeeId.Value) : new SqlParameter("@PayeeId", DBNull.Value),
                leadId.HasValue ? new SqlParameter("@LeadId", leadId.Value) : new SqlParameter("@LeadId", DBNull.Value),
                new SqlParameter("@Pageno", pageNo),
                new SqlParameter("@Pagesize", pageSize)
            };
            return DbContext.CRMFollowUpList.FromSqlRaw(
                "[dbo].[CRMFollowUp_GetByEntity] @PayeeId,@LeadId,@Pageno,@Pagesize",
                param);
        }

        public int GetOverdueCount(int empId)
        {
            var empIdParam = new SqlParameter("@EmpId", empId);
            var countParam = new SqlParameter()
            {
                ParameterName = "@OverdueCount",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[CRMFollowUp_OverdueCount] @EmpId, @OverdueCount OUTPUT",
                empIdParam, countParam);

            return Convert.ToInt32(countParam.Value);
        }

        private static object[] BuildParams(CRMFollowUpListReq req)
        {
            object[] param = {
                new SqlParameter("@Pageno", req.Pageno),
                new SqlParameter("@Pagesize", req.Pagesize),
                string.IsNullOrEmpty(req.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", req.Search),
                string.IsNullOrEmpty(req.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", req.SortField),
                string.IsNullOrEmpty(req.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", req.SortOrder),
                req.AssignedTo.HasValue ? new SqlParameter("@AssignedTo", req.AssignedTo.Value) : new SqlParameter("@AssignedTo", DBNull.Value),
                string.IsNullOrEmpty(req.Status) ? new SqlParameter("@Status", DBNull.Value) : new SqlParameter("@Status", req.Status),
                string.IsNullOrEmpty(req.Priority) ? new SqlParameter("@Priority", DBNull.Value) : new SqlParameter("@Priority", req.Priority),
                req.StartDate.HasValue ? new SqlParameter("@StartDate", req.StartDate.Value) : new SqlParameter("@StartDate", DBNull.Value),
                req.EndDate.HasValue ? new SqlParameter("@EndDate", req.EndDate.Value) : new SqlParameter("@EndDate", DBNull.Value),
                new SqlParameter("@IsCount", req.IsCount),
                new SqlParameter() { ParameterName = "@TotalCount", Direction = System.Data.ParameterDirection.Output, SqlDbType = System.Data.SqlDbType.Int },
                new SqlParameter("@EmpId", UserContext.EmpId)
            };
            return param;
        }
    }
}
