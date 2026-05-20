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
    public class IncomingPaymentRepository : KLSRepository<CustomerPayment>, IIncomingPaymentRepository
    {
        public IncomingPaymentRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<IncomingPaymentList> GetPagedList(IncomingPaymentListReq incomingPaymentReq)
        {
            var param = BuildParam(incomingPaymentReq);

            return DbContext.IncomingPaymentList.FromSqlRaw("[dbo].[IncomingPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(IncomingPaymentListReq incomingPaymentReq)
        {
            incomingPaymentReq.IsCount = true;
            var param = BuildParam(incomingPaymentReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[IncomingPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[9] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildParam(IncomingPaymentListReq incomingPaymentReq)
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

        public int Save(IncomingPaymentReq incomingPaymentReq)
        {
            var CustomerPaymentIdParam = new SqlParameter("@CustomerPaymentId", incomingPaymentReq.CustomerPaymentId);

            var PayeeIdParam = new SqlParameter("@PayeeId", incomingPaymentReq.PayeeId);

            var PaymentDateParam = new SqlParameter("@PaymentDate", incomingPaymentReq.PaymentDate);

            var PaymentMethodParam = (!string.IsNullOrEmpty(incomingPaymentReq.PaymentMethod)) ? new SqlParameter("@PaymentMethod", incomingPaymentReq.PaymentMethod) : new SqlParameter("@PaymentMethod", DBNull.Value);

            var FromAccountIdParam = new SqlParameter("@FromAccountId", incomingPaymentReq.FromAccountId);

            var ReferenceIdParam = (!string.IsNullOrEmpty(incomingPaymentReq.ReferenceId)) ? new SqlParameter("@ReferenceId", incomingPaymentReq.ReferenceId) : new SqlParameter("@ReferenceId", DBNull.Value);

            var PaymentAmountParam = new SqlParameter("@PaymentAmount", incomingPaymentReq.PaymentAmount);

            var NotesParam = (!string.IsNullOrEmpty(incomingPaymentReq.Notes)) ? new SqlParameter("@Notes", incomingPaymentReq.Notes) : new SqlParameter("@Notes", DBNull.Value);

            var AccountId1Param = incomingPaymentReq.AccountId1.HasValue ? new SqlParameter("@AccountId1", incomingPaymentReq.AccountId1) : new SqlParameter("@AccountId1", DBNull.Value);

            var AccountId2Param = incomingPaymentReq.AccountId2.HasValue ? new SqlParameter("@AccountId2", incomingPaymentReq.AccountId2) : new SqlParameter("@AccountId2", DBNull.Value);

            var AccountId3Param = incomingPaymentReq.AccountId3.HasValue ? new SqlParameter("@AccountId3", incomingPaymentReq.AccountId3) : new SqlParameter("@AccountId3", DBNull.Value);

            var AccountId4Param = incomingPaymentReq.AccountId4.HasValue ? new SqlParameter("@AccountId4", incomingPaymentReq.AccountId4) : new SqlParameter("@AccountId4", DBNull.Value);

            var Amount1Param = incomingPaymentReq.Amount1.HasValue ? new SqlParameter("@Amount1", incomingPaymentReq.Amount1) : new SqlParameter("@Amount1", DBNull.Value);

            var Amount2Param = incomingPaymentReq.Amount2.HasValue ? new SqlParameter("@Amount2", incomingPaymentReq.Amount2) : new SqlParameter("@Amount2", DBNull.Value);

            var Amount3Param = incomingPaymentReq.Amount3.HasValue ? new SqlParameter("@Amount3", incomingPaymentReq.Amount3) : new SqlParameter("@Amount3", DBNull.Value);

            var Amount4Param = incomingPaymentReq.Amount4.HasValue ? new SqlParameter("@Amount4", incomingPaymentReq.Amount4) : new SqlParameter("@Amount4", DBNull.Value);

            var NewCustomerPaymentId = new SqlParameter()
            {
                ParameterName = "@NewCustomerPaymentId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[IncomingPayment_Insert] @CustomerPaymentId,@PayeeId,@PaymentDate,@PaymentMethod,@FromAccountId,@ReferenceId,@PaymentAmount,@Notes,@AccountId1,@AccountId2,@AccountId3,@AccountId4,@Amount1,@Amount2,@Amount3,@Amount4,@NewCustomerPaymentId OUTPUT", CustomerPaymentIdParam, PayeeIdParam, PaymentDateParam, PaymentMethodParam, FromAccountIdParam, ReferenceIdParam, PaymentAmountParam, NotesParam, AccountId1Param, AccountId2Param, AccountId3Param, AccountId4Param, Amount1Param, Amount2Param, Amount3Param, Amount4Param, NewCustomerPaymentId);

            return Convert.ToInt32(NewCustomerPaymentId.Value);
        }
    }
}
