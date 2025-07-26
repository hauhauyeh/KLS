using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Data.Repositories;
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
    public class EmailLogRepository : KLSRepository<EmailLog>, IEmailLogRepository
    {
        public EmailLogRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<EmailLogDTO> GetEmailLogs(EmailLogReq emailLogReq)
        {
            var param = BuildParam(emailLogReq);

            return DbContext.EmailLogDTO.FromSqlRaw("[dbo].[EmailLog_GetAllList] @Pageno,@Pagesize,@EmailDate,@Search,@Filterby,@IsCount", param);
        }

        private static object[] BuildParam(EmailLogReq emailLogReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", emailLogReq.Pageno),
                new SqlParameter("@Pagesize", emailLogReq.Pagesize),
                emailLogReq.EmailDate.HasValue ? new SqlParameter("@EmailDate", emailLogReq.EmailDate) : new SqlParameter("@EmailDate", DBNull.Value),
                string.IsNullOrEmpty(emailLogReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", emailLogReq.Search),
                string.IsNullOrEmpty(emailLogReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", emailLogReq.Filterby),
                new SqlParameter("@IsCount", emailLogReq.IsCount)
            };

            return param;
        }
    }
}