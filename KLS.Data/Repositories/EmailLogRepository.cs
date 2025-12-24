using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Data.Repositories;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Org.BouncyCastle.Ocsp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class EmailLogRepository : KLSRepository<EmailLog>, IEmailLogRepository
    {
        public EmailLogRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<EmailLogDTO> GetPagedList(EmailLogReq emailLogReq)
        {
            var param = BuildEmailLogsParam(emailLogReq);

            return DbContext.EmailLogDTO.FromSqlRaw("[dbo].[EmailLog_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(EmailLogReq emailLogReq)
        {
            emailLogReq.IsCount = true;
            var param = BuildEmailLogsParam(emailLogReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[EmailLog_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[9] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildEmailLogsParam(EmailLogReq emailLogReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", emailLogReq.Pageno),

                new SqlParameter("@Pagesize", emailLogReq.Pagesize),

                string.IsNullOrEmpty(emailLogReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", emailLogReq.Search),

                emailLogReq.StartDate.HasValue ? new SqlParameter("@StartDate", emailLogReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                emailLogReq.EndDate.HasValue ? new SqlParameter("@EndDate", emailLogReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                string.IsNullOrEmpty(emailLogReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", emailLogReq.Filterby),

                string.IsNullOrEmpty(emailLogReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", emailLogReq.SortField),

                string.IsNullOrEmpty(emailLogReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", emailLogReq.SortOrder),

                new SqlParameter("@IsCount", emailLogReq.IsCount),

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