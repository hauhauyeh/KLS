using KLS.Common;
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
    public class TempCustomerPaymentRepository : KLSRepository<TempCustomerPayment>, ITempCustomerPaymentRepository
    {
        public TempCustomerPaymentRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public IQueryable<TempCustomerPaymentList>? GetList(TempPaymentReq tempPaymentReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", tempPaymentReq.PayeeId);

            var CustomerPaymentIdParam = new SqlParameter("@CustomerPaymentId", tempPaymentReq.PaymentId);

            var TempIdParam = tempPaymentReq.TempId.HasValue ? new SqlParameter("@Id", tempPaymentReq.TempId) : new SqlParameter("@Id", DBNull.Value);

            return DbContext.TempCustomerPaymentList.FromSqlRaw("[dbo].[TempCustomerPayment_GetList] @EmpId,@PayeeId,@CustomerPaymentId,@Id", EmpIdParam, PayeeIdParam, CustomerPaymentIdParam, TempIdParam);
        }

        public void Inject(TempPaymentReq tempPaymentReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", tempPaymentReq.PayeeId);

            var CustomerPaymentIdParam = new SqlParameter("@CustomerPaymentId", tempPaymentReq.PaymentId);

            var PaymentTypeParam = (!string.IsNullOrEmpty(tempPaymentReq.PaymentType)) ? new SqlParameter("@PaymentType", tempPaymentReq.PaymentType) : new SqlParameter("@PaymentType", DBNull.Value);

            var AllowFutureInvoicesParam = new SqlParameter("@AllowFutureInvoices", tempPaymentReq.AllowFutureInvoices);

            DbContext.Database.ExecuteSqlRaw("[dbo].[CustomerPayment_Inject] @EmpId,@PayeeId,@CustomerPaymentId,@PaymentType,@AllowFutureInvoices", EmpIdParam, PayeeIdParam, CustomerPaymentIdParam, PaymentTypeParam, AllowFutureInvoicesParam);
        }

        public int InsertInvoice(TempPaymentReq tempPaymentReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var CustomerPaymentIdParam = new SqlParameter("@CustomerPaymentId", tempPaymentReq.PaymentId);

            var SalesNumberParam = new SqlParameter("@SalesNumber", tempPaymentReq.TempId);

            var NewTempId = new SqlParameter()
            {
                ParameterName = "@TempId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[TempCustomerPayment_InsertInvoice] @EmpId,@CustomerPaymentId,@SalesNumber,@TempId OUTPUT", EmpIdParam, CustomerPaymentIdParam, SalesNumberParam, NewTempId);

            return Convert.ToInt32(NewTempId.Value);
        }
    }
}
