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
    public class TempVendorPaymentRepository : KLSRepository<TempVendorPayment>, ITempVendorPaymentRepository
    {
        public TempVendorPaymentRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<TempVendorPayment> InjectTempVendorPayment(TempVendorPaymentListReq tempVendorPaymentListReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", tempVendorPaymentListReq.PayeeId);

            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", tempVendorPaymentListReq.VendorPaymentId);

            var PaymentTypeParam = (!string.IsNullOrEmpty(tempVendorPaymentListReq.PaymentType)) ? new SqlParameter("@PaymentType", tempVendorPaymentListReq.PaymentType) : new SqlParameter("@PaymentType", DBNull.Value);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_Inject] @EmpId,@PayeeId,@VendorPaymentId,@PaymentType", EmpIdParam, PayeeIdParam, VendorPaymentIdParam, PaymentTypeParam);

            return DbContext.TempVendorPayments.Where(c => c.VendorPaymentId == tempVendorPaymentListReq.VendorPaymentId && c.PayeeId == tempVendorPaymentListReq.PayeeId && c.EmpId == tempVendorPaymentListReq.EmpId).Include(c => c.Purchase).OrderBy(c => c.Purchase.ArrivalDate).ThenBy(c => c.TempVPId);
        }
    }
}
