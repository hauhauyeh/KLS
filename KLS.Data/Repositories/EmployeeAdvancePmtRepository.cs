using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
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
    public class EmployeeAdvancePmtRepository : KLSRepository<VendorPayment>, IEmployeeAdvancePmtRepository
    {
        public EmployeeAdvancePmtRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<EmployeeAdvancePmt> GetAllEmployeeAdvancePmt(EmployeeAdvancePmtReq employeeAdvancePmtReq)
        {
            var param = BuildEmployeeAdvancePmtParam(employeeAdvancePmtReq);

            return DbContext.EmployeeAdvancePmts.FromSqlRaw("[dbo].[EmpAdvance_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllEmployeeAdvancePmt(EmployeeAdvancePmtReq employeeAdvancePmtReq)
        {
            employeeAdvancePmtReq.IsCount = true;
            var param = BuildEmployeeAdvancePmtParam(employeeAdvancePmtReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[EmpAdvance_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[9] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildEmployeeAdvancePmtParam(EmployeeAdvancePmtReq employeeAdvancePmtReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", employeeAdvancePmtReq.Pageno),

                new SqlParameter("@Pagesize", employeeAdvancePmtReq.Pagesize),

                string.IsNullOrEmpty(employeeAdvancePmtReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", employeeAdvancePmtReq.Search),

                employeeAdvancePmtReq.StartDate.HasValue ? new SqlParameter("@StartDate", employeeAdvancePmtReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                employeeAdvancePmtReq.EndDate.HasValue ? new SqlParameter("@EndDate", employeeAdvancePmtReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                employeeAdvancePmtReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", employeeAdvancePmtReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(employeeAdvancePmtReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", employeeAdvancePmtReq.SortField),

                string.IsNullOrEmpty(employeeAdvancePmtReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", employeeAdvancePmtReq.SortOrder),

                new SqlParameter("@IsCount", employeeAdvancePmtReq.IsCount),

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