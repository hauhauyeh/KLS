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
    public class EmployeeRepository : KLSRepository<Employee>, IEmployeeRepository
    {
        public EmployeeRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<EmployeeList> GetAllEmployees(EmpReq empReq)
        {
            var SearchParam = (!string.IsNullOrEmpty(empReq.Search)) ? new SqlParameter("@Search", empReq.Search) : new SqlParameter("@Search", DBNull.Value);

            var EmpStatusParam = empReq.EmpStatus.HasValue ? new SqlParameter("@EmpStatus", empReq.EmpStatus) : new SqlParameter("@EmpStatus", DBNull.Value);

            var SortFieldParam = (!string.IsNullOrEmpty(empReq.SortField)) ? new SqlParameter("@SortField", empReq.SortField) : new SqlParameter("@SortField", DBNull.Value);

            var SortOrderParam = (!string.IsNullOrEmpty(empReq.SortOrder)) ? new SqlParameter("@SortOrder", empReq.SortOrder) : new SqlParameter("@SortOrder", DBNull.Value);

            return DbContext.EmployeeList.FromSqlRaw("[dbo].[Employee_GetAllList] @Search,@EmpStatus,@SortField,@SortOrder", SearchParam, EmpStatusParam, SortFieldParam, SortOrderParam);
        }

        public IQueryable<PayeeSearch>? SearchEmployee(PayeeSearchReq searchReq)
        {
            var TermParam = string.IsNullOrEmpty(searchReq.Term) ? new SqlParameter("@SearchTerm", DBNull.Value) : new SqlParameter("@SearchTerm", searchReq.Term);

            var IsActiveParam = new SqlParameter("@IsActive", searchReq.IsActiveOnly);

            return DbContext.PayeeSearch.FromSqlRaw("[dbo].[Employee_SearchbyTerm] @SearchTerm,@IsActive", TermParam, IsActiveParam);
        }
    }
}
