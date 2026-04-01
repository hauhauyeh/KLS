using KLS.Common;
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
    public class CustomerRepository : KLSRepository<Customer>, ICustomerRepository
    {
        public CustomerRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<CustomerList> GetPagedList(CustomerListReq customerListReq)
        {
            var param = BuildCustomersParam(customerListReq);

            return DbContext.CustomerList.FromSqlRaw("[dbo].[Customer_GetAllList] @Pageno,@Pagesize,@Search,@Filterby,@Content,@Sortby,@Category,@EmpId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(CustomerListReq customerListReq)
        {
            customerListReq.IsCount = true;
            var param = BuildCustomersParam(customerListReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Customer_GetAllList] @Pageno,@Pagesize,@Search,@Filterby,@Content,@Sortby,@Category,@EmpId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[11] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        public IQueryable<PayeeSearch>? Search(PayeeSearchReq searchReq)
        {
            var TermParam = string.IsNullOrEmpty(searchReq.Term) ? new SqlParameter("@SearchTerm", DBNull.Value) : new SqlParameter("@SearchTerm", searchReq.Term);

            var IsActiveOnlyParam = new SqlParameter("@IsActiveOnly", searchReq.IsActiveOnly);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.IsAdmin ? 0 : UserContext.EmpId);

            var IsSearchSalesParam = new SqlParameter("@IsSearchSales", searchReq.IsSearchSales);

            return DbContext.PayeeSearch.FromSqlRaw("[dbo].[Customer_SearchByTerm] @SearchTerm,@IsActiveOnly,@EmpId,@IsSearchSales", TermParam, IsActiveOnlyParam, EmpIdParam, IsSearchSalesParam);
        }

        public IQueryable<PayeeExport> Export()
        {
            return DbContext.PayeeExport.FromSqlRaw("[dbo].[Customer_Export]");
        }

        public DateOnly GetNextShipDate(int payeeId)
        {
            var payeeIdParam = new SqlParameter("@PayeeId", payeeId);
            var shipDateParam = new SqlParameter()
            {
                ParameterName = "@ShipDate",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Date
            };

            DbContext.Database.ExecuteSqlRaw(
                "[dbo].[Web_Customer_NextShipDate] @PayeeId, @ShipDate OUTPUT",
                payeeIdParam, shipDateParam);

            return DateOnly.FromDateTime((DateTime)shipDateParam.Value);
        }

        private static object[] BuildCustomersParam(CustomerListReq customerListReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", customerListReq.Pageno),

                new SqlParameter("@Pagesize", customerListReq.Pagesize),

                string.IsNullOrEmpty(customerListReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", customerListReq.Search),

                string.IsNullOrEmpty(customerListReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", customerListReq.Filterby),

                string.IsNullOrEmpty(customerListReq.Content) ? new SqlParameter("@Content", DBNull.Value) : new SqlParameter("@Content", customerListReq.Content),

                string.IsNullOrEmpty(customerListReq.Sortby) ? new SqlParameter("@Sortby", DBNull.Value) : new SqlParameter("@Sortby", customerListReq.Sortby),

                string.IsNullOrEmpty(customerListReq.Category) ? new SqlParameter("@Category", DBNull.Value) : new SqlParameter("@Category", customerListReq.Category),

                new SqlParameter("@EmpId", UserContext.EmpId),

                string.IsNullOrEmpty(customerListReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", customerListReq.SortField),

                string.IsNullOrEmpty(customerListReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", customerListReq.SortOrder),

                new SqlParameter("@IsCount", customerListReq.IsCount),

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