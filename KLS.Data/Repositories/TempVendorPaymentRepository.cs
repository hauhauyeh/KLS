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

        public IQueryable<TempVendorPayment> Inject(TempVendorPaymentListReq tempReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayeeIdParam = new SqlParameter("@PayeeId", tempReq.PayeeId);

            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", tempReq.VendorPaymentId);

            var PaymentTypeParam = (!string.IsNullOrEmpty(tempReq.PaymentType)) ? new SqlParameter("@PaymentType", tempReq.PaymentType) : new SqlParameter("@PaymentType", DBNull.Value);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_Inject] @EmpId,@PayeeId,@VendorPaymentId,@PaymentType", EmpIdParam, PayeeIdParam, VendorPaymentIdParam, PaymentTypeParam);

            return DbContext.TempVendorPayments.Where(c => c.VendorPaymentId == tempReq.VendorPaymentId && c.PayeeId == tempReq.PayeeId && c.EmpId == UserContext.EmpId).Include(c => c.Purchase).OrderBy(c => c.Purchase.ArrivalDate).ThenBy(c => c.TempVPId);
        }
    }
}
