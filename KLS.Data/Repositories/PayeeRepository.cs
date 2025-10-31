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
    public class PayeeRepository : KLSRepository<Payee>, IPayeeRepository
    {
        public PayeeRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<PayeeSearch>? SearchPayee(PayeeSearchReq searchReq)
        {
            var TermParam = string.IsNullOrEmpty(searchReq.Term) ? new SqlParameter("@SearchTerm", DBNull.Value) : new SqlParameter("@SearchTerm", searchReq.Term);

            var IsActiveOnlyParam = new SqlParameter("@IsActiveOnly", searchReq.IsActiveOnly);

            return DbContext.PayeeSearch.FromSqlRaw("[dbo].[Payee_SearchByTerm] @SearchTerm,@IsActiveOnly", TermParam, IsActiveOnlyParam);
        }

        public IQueryable<ARCustomerList> GetARCustomers(ARCustomerListReq aRCustomerListReq)
        {
            var param = BuildARCustomerParam(aRCustomerListReq);

            return DbContext.ARCustomerList.FromSqlRaw("[dbo].[Payee_ARList] @Pageno,@Pagesize,@Search,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllARCustomer(ARCustomerListReq aRCustomerListReq)
        {
            aRCustomerListReq.IsCount = true;
            var param = BuildARCustomerParam(aRCustomerListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Payee_ARList] @Pageno,@Pagesize,@Search,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[7] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildARCustomerParam(ARCustomerListReq aRCustomerListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", aRCustomerListReq.Pageno),

                new SqlParameter("@Pagesize", aRCustomerListReq.Pagesize),

                string.IsNullOrEmpty(aRCustomerListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", aRCustomerListReq.Search),

                string.IsNullOrEmpty(aRCustomerListReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", aRCustomerListReq.Filterby),

                string.IsNullOrEmpty(aRCustomerListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", aRCustomerListReq.SortField),

                string.IsNullOrEmpty(aRCustomerListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", aRCustomerListReq.SortOrder),

                new SqlParameter("@IsCount", aRCustomerListReq.IsCount),

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
