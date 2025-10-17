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
    public class IncomingPaymentRepository : KLSRepository<CustomerPayment>, IIncomingPaymentRepository
    {
        public IncomingPaymentRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<IncomingPaymentList> GetIncomingPayments(IncomingPaymentReq incomingPaymentReq)
        {
            var param = BuildIncomingPaymentsParam(incomingPaymentReq);

            return DbContext.IncomingPaymentList.FromSqlRaw("[dbo].[IncomingPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllIncomingPayments(IncomingPaymentReq incomingPaymentReq)
        {
            incomingPaymentReq.IsCount = true;
            var param = BuildIncomingPaymentsParam(incomingPaymentReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[IncomingPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[9] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildIncomingPaymentsParam(IncomingPaymentReq incomingPaymentReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", incomingPaymentReq.Pageno),

                new SqlParameter("@Pagesize", incomingPaymentReq.Pagesize),

                (!string.IsNullOrEmpty(incomingPaymentReq.Search)) ? new SqlParameter("@Search", incomingPaymentReq.Search) : new SqlParameter("@Search", DBNull.Value),

                incomingPaymentReq.StartDate.HasValue ? new SqlParameter("@StartDate", incomingPaymentReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                incomingPaymentReq.EndDate.HasValue ? new SqlParameter("@EndDate", incomingPaymentReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                string.IsNullOrEmpty(incomingPaymentReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", incomingPaymentReq.SortField),

                string.IsNullOrEmpty(incomingPaymentReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", incomingPaymentReq.SortOrder),

                incomingPaymentReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", incomingPaymentReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                new SqlParameter("@IsCount", incomingPaymentReq.IsCount),

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
