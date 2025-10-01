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
    public class PayrollDetailRepository : KLSRepository<PayrollDetail>, IPayrollDetailRepository
    {
        public PayrollDetailRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<PayrollList> GetAllPayrolls(PayrollReq payrollReq)
        {
            var param = BuildPayrollParam(payrollReq);

            return DbContext.PayrollList.FromSqlRaw("[dbo].[PayrollDetail_GetAllList] @Pageno,@Pagesize,@StartDate,@EndDate,@PayeeId,@Search,@Filterby,@IsCount", param);
        }

        private static object[] BuildPayrollParam(PayrollReq payrollReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", payrollReq.Pageno),

                new SqlParameter("@Pagesize", payrollReq.Pagesize),

                payrollReq.StartDate.HasValue ? new SqlParameter("@StartDate", payrollReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                payrollReq.EndDate.HasValue ? new SqlParameter("@EndDate", payrollReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                payrollReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", payrollReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(payrollReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", payrollReq.Search),

                string.IsNullOrEmpty(payrollReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", payrollReq.Filterby),
                new SqlParameter("@IsCount", payrollReq.IsCount),
            };

            return param;
        }
    }
}