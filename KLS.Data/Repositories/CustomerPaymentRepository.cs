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
    public class CustomerPaymentRepository : KLSRepository<CustomerPayment>, ICustomerPaymentRepository
    {
        public CustomerPaymentRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<CustomerPaymentList> GetCustomerPayment(CustomerPaymentReq customerPaymentReq)
        {
            var param = BuildCustomerPaymentParam(customerPaymentReq);

            return DbContext.CustomerPaymentList.FromSqlRaw("[dbo].[CustomerPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllCustomerPayment(CustomerPaymentReq customerPaymentReq)
        {
            customerPaymentReq.IsCount = true;
            var param = BuildCustomerPaymentParam(customerPaymentReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[CustomerPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[10] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildCustomerPaymentParam(CustomerPaymentReq customerPaymentReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", customerPaymentReq.Pageno),

                new SqlParameter("@Pagesize", customerPaymentReq.Pagesize),

                string.IsNullOrEmpty(customerPaymentReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", customerPaymentReq.Search),

                customerPaymentReq.StartDate.HasValue ? new SqlParameter("@StartDate", customerPaymentReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                customerPaymentReq.EndDate.HasValue ? new SqlParameter("@EndDate", customerPaymentReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                string.IsNullOrEmpty(customerPaymentReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", customerPaymentReq.Filterby),

                customerPaymentReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", customerPaymentReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(customerPaymentReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", customerPaymentReq.SortField),

                string.IsNullOrEmpty(customerPaymentReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", customerPaymentReq.SortOrder),

                new SqlParameter("@IsCount", customerPaymentReq.IsCount),

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