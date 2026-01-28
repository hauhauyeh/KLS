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

        public IQueryable<TempCustomerPaymentList>? Inject(TempPaymentReq tempPaymentReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", tempPaymentReq.PayeeId);

            var CustomerPaymentIdParam = new SqlParameter("@CustomerPaymentId", tempPaymentReq.PaymentId);

            var PaymentTypeParam = (!string.IsNullOrEmpty(tempPaymentReq.PaymentType)) ? new SqlParameter("@PaymentType", tempPaymentReq.PaymentType) : new SqlParameter("@PaymentType", DBNull.Value);

            return DbContext.TempCustomerPaymentList.FromSqlRaw("[dbo].[CustomerPayment_Inject] @EmpId,@PayeeId,@CustomerPaymentId,@PaymentType", EmpIdParam, PayeeIdParam, CustomerPaymentIdParam, PaymentTypeParam);
        }
    }
}
