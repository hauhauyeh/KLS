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
    public class CustomerPaymentRepository : KLSRepository<CustomerPayment>, ICustomerPaymentRepository
    {
        public CustomerPaymentRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<CustomerPaymentList> GetPagedList(CustomerPaymentReq customerPaymentReq)
        {
            var param = BuildPagedList(customerPaymentReq);

            return DbContext.CustomerPaymentList.FromSqlRaw("[dbo].[CustomerPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(CustomerPaymentReq customerPaymentReq)
        {
            customerPaymentReq.IsCount = true;
            var param = BuildPagedList(customerPaymentReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[CustomerPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@Filterby,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[10] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildPagedList(CustomerPaymentReq customerPaymentReq)
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

        public int Save(CustomerPaymentSaveReq paymentSaveReq)
        {
            var CustomerPaymentIdParam = new SqlParameter("@CustomerPaymentId", paymentSaveReq.CustomerPaymentId);

            var PaymentTypeParam = (!string.IsNullOrEmpty(paymentSaveReq.PaymentType)) ? new SqlParameter("@PaymentType", paymentSaveReq.PaymentType) : new SqlParameter("@PaymentType", DBNull.Value);

            var PayeeIdParam = new SqlParameter("@PayeeId", paymentSaveReq.PayeeId);

            var PaymentDateParam = paymentSaveReq.PaymentDate.HasValue ? new SqlParameter("@PaymentDate", paymentSaveReq.PaymentDate) : new SqlParameter("@PaymentDate", DBNull.Value);

            var PaymentMethodParam = (!string.IsNullOrEmpty(paymentSaveReq.PaymentMethod)) ? new SqlParameter("@PaymentMethod", paymentSaveReq.PaymentMethod) : new SqlParameter("@PaymentMethod", DBNull.Value);

            var FromAccountIdParam = paymentSaveReq.FromAccountId.HasValue ? new SqlParameter("@FromAccountId", paymentSaveReq.FromAccountId) : new SqlParameter("@FromAccountId", DBNull.Value);

            var ReferenceIdParam = (!string.IsNullOrEmpty(paymentSaveReq.ReferenceId)) ? new SqlParameter("@ReferenceId", paymentSaveReq.ReferenceId) : new SqlParameter("@ReferenceId", DBNull.Value);

            var PaymentAmountParam = paymentSaveReq.PaymentAmount.HasValue ? new SqlParameter("@PaymentAmount", paymentSaveReq.PaymentAmount) : new SqlParameter("@PaymentAmount", DBNull.Value);

            var NotesParam = (!string.IsNullOrEmpty(paymentSaveReq.Notes)) ? new SqlParameter("@Notes", paymentSaveReq.Notes) : new SqlParameter("@Notes", DBNull.Value);

            var CCFeeParam = paymentSaveReq.CCFee.HasValue ? new SqlParameter("@CCFee", paymentSaveReq.CCFee) : new SqlParameter("@CCFee", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var NewPaymentId = new SqlParameter()
            {
                ParameterName = "@NewPaymentId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[CustomerPayment_Insert] @CustomerPaymentId,@PaymentType,@PayeeId,@PaymentDate,@PaymentMethod,@FromAccountId,@ReferenceId,@PaymentAmount,@Notes,@CCFee,@EmpId,@NewPaymentId OUTPUT", CustomerPaymentIdParam, PaymentTypeParam, PayeeIdParam, PaymentDateParam, PaymentMethodParam, FromAccountIdParam, ReferenceIdParam, PaymentAmountParam, NotesParam, CCFeeParam, EmpIdParam, NewPaymentId);

            return Convert.ToInt32(NewPaymentId.Value);
        }

        public void SaveReturn(CustomerPaymentReturnReq returnReq)
        {
            var CustomerPaymentIdParam = new SqlParameter("@CustomerPaymentId", returnReq.CustomerPaymentId);

            var ReturnTypeParam = string.IsNullOrEmpty(returnReq.ReturnType) ? new SqlParameter("@ReturnType", DBNull.Value) : new SqlParameter("@ReturnType", returnReq.ReturnType);

            var ReturnDateParam = returnReq.ReturnDate.HasValue ? new SqlParameter("@ReturnDate", returnReq.ReturnDate) : new SqlParameter("@ReturnDate", DBNull.Value);

            var FeeAccountIdParam = returnReq.FeeAccountId.HasValue ? new SqlParameter("@FeeAccountId", returnReq.FeeAccountId) : new SqlParameter("@FeeAccountId", DBNull.Value);

            var FeeAmountParam = returnReq.FeeAmount.HasValue ? new SqlParameter("@FeeAmount", returnReq.FeeAmount) : new SqlParameter("@FeeAmount", DBNull.Value);

            var NSFFeeParam = returnReq.NSFFee.HasValue ? new SqlParameter("@NSFFee", returnReq.NSFFee) : new SqlParameter("@NSFFee", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[CustomerPayment_InsertReturn] @CustomerPaymentId,@ReturnType,@ReturnDate,@FeeAccountId,@FeeAmount,@NSFFee,@EmpId", CustomerPaymentIdParam, ReturnTypeParam, ReturnDateParam, FeeAccountIdParam, FeeAmountParam, NSFFeeParam, EmpIdParam);
        }

        public void DeleteReturn(int customerPaymentId)
        {
            var CustomerPaymentIdParam = new SqlParameter("@CustomerPaymentId", customerPaymentId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[CustomerPayment_DeleteReturn] @CustomerPaymentId", CustomerPaymentIdParam);
        }

        public IQueryable<CustomerPaymentStatement>? Statement(int payeeId)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", payeeId);

            return DbContext.CustomerPaymentStatement.FromSqlRaw("[dbo].[CustomerPayment_GetStmt] @PayeeId", PayeeIdParam);
        }
    }
}