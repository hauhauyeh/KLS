using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Org.BouncyCastle.Ocsp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class EmployeeRepository : KLSRepository<Employee>, IEmployeeRepository
    {
        public EmployeeRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<EmployeeList> GetPagedList(EmpReq empReq)
        {
            var param = BuildEmployeesParam(empReq);

            return DbContext.EmployeeList.FromSqlRaw("[dbo].[Employee_GetAllList] @Search,@EmpStatus,@SortField,@SortOrder", param);
        }

        private static object[] BuildEmployeesParam(EmpReq empReq)
        {
            object[] param = {

                string.IsNullOrEmpty(empReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", empReq.Search),

                empReq.EmpStatus.HasValue ? new SqlParameter("@EmpStatus", empReq.EmpStatus) : new SqlParameter("@EmpStatus", DBNull.Value),

                string.IsNullOrEmpty(empReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", empReq.SortField),

                string.IsNullOrEmpty(empReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", empReq.SortOrder),
            };

            return param;
        }

        public IQueryable<PayeeSearch>? Search(PayeeSearchReq searchReq)
        {
            var TermParam = string.IsNullOrEmpty(searchReq.Term) ? new SqlParameter("@SearchTerm", DBNull.Value) : new SqlParameter("@SearchTerm", searchReq.Term);

            var IsActiveOnlyParam = new SqlParameter("@IsActiveOnly", searchReq.IsActiveOnly);

            return DbContext.PayeeSearch.FromSqlRaw("[dbo].[Employee_SearchByTerm] @SearchTerm,@IsActiveOnly", TermParam, IsActiveOnlyParam);
        }
    }
}
