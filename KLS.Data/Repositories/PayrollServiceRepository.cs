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
    public class PayrollServiceRepository : KLSRepository<PayrollService>, IPayrollServiceRepository
    {
        public PayrollServiceRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<PayrollServiceDTO> GetPayrollService(PayrollServiceReq payrollServiceReq)
        {
            var param = BuildParam(payrollServiceReq);

            return DbContext.PayrollServiceDTO.FromSqlRaw("[dbo].[PayrollService_GetAllList] @Pageno,@Pagesize,@Search,@IsCount", param);
        }

        private static object[] BuildParam(PayrollServiceReq payrollServiceReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", payrollServiceReq.Pageno),
                new SqlParameter("@Pagesize", payrollServiceReq.Pagesize),
                //payrollServiceReq.StartDate.HasValue ? new SqlParameter("@StartDate", payrollServiceReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),
                //payrollServiceReq.EndDate.HasValue ? new SqlParameter("@EndDate", payrollServiceReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),
                string.IsNullOrEmpty(payrollServiceReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", payrollServiceReq.Search),
                //string.IsNullOrEmpty(emailLogReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", emailLogReq.Filterby),
                new SqlParameter("@IsCount", payrollServiceReq.IsCount)
            };

            return param;
        }
    }
}