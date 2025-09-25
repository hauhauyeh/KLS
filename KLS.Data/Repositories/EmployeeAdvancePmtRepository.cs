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
    public class EmployeeAdvancePmtRepository : KLSRepository<VendorPayment>, IEmployeeAdvancePmtRepository
    {
        public EmployeeAdvancePmtRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<EmployeeAdvancePmt> GetAllEmployeeAdvancePmt(EmployeeAdvancePmtReq employeeAdvancePmtReq)
        {
            var param = BuildParam(employeeAdvancePmtReq);

            return DbContext.EmployeeAdvancePmts.FromSqlRaw("[dbo].[EmpAdvance_GetAllList] @Pageno,@Pagesize,@StartDate,@EndDate,@PayeeId,@Search,@IsCount", param);
        }

        private static object[] BuildParam(EmployeeAdvancePmtReq employeeAdvancePmtReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", employeeAdvancePmtReq.Pageno),

                new SqlParameter("@Pagesize", employeeAdvancePmtReq.Pagesize),

                employeeAdvancePmtReq.StartDate.HasValue ? new SqlParameter("@StartDate", employeeAdvancePmtReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                employeeAdvancePmtReq.EndDate.HasValue ? new SqlParameter("@EndDate", employeeAdvancePmtReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                employeeAdvancePmtReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", employeeAdvancePmtReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(employeeAdvancePmtReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", employeeAdvancePmtReq.Search),

                //string.IsNullOrEmpty(employeeAdvancePmtReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", employeeAdvancePmtReq.Filterby),
                new SqlParameter("@IsCount", employeeAdvancePmtReq.IsCount),
            };

            return param;
        }
    }
}