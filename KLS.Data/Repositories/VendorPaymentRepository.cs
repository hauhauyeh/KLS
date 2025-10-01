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
    public class VendorPaymentRepository : KLSRepository<VendorPayment>, IVendorPaymentRepository
    {
        public VendorPaymentRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<CheckRegister> GetCheckRegister(CheckRegisterReq checkRegisterReq)
        {
            var param = BuildParam(checkRegisterReq);

            return DbContext.CheckRegister.FromSqlRaw("[dbo].[CheckRegister_GetAllList] @Pageno,@Pagesize,@StartDate,@EndDate,@PayeeId,@Search,@FromAccount,@PaymentMethod,@Filterby,@IsCount", param);
        }

        private static object[] BuildParam(CheckRegisterReq checkRegisterReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", checkRegisterReq.Pageno),

                new SqlParameter("@Pagesize", checkRegisterReq.Pagesize),

                checkRegisterReq.StartDate.HasValue ? new SqlParameter("@StartDate", checkRegisterReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                checkRegisterReq.EndDate.HasValue ? new SqlParameter("@EndDate", checkRegisterReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                checkRegisterReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", checkRegisterReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(checkRegisterReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", checkRegisterReq.Search),

                string.IsNullOrEmpty(checkRegisterReq.FromAccount) ? new SqlParameter("@FromAccount", DBNull.Value) : new SqlParameter("@FromAccount", checkRegisterReq.FromAccount),

                string.IsNullOrEmpty(checkRegisterReq.PaymentMethod) ? new SqlParameter("@PaymentMethod", DBNull.Value) : new SqlParameter("@PaymentMethod", checkRegisterReq.PaymentMethod),

                string.IsNullOrEmpty(checkRegisterReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", checkRegisterReq.Filterby),
                new SqlParameter("@IsCount", checkRegisterReq.IsCount),
            };

            return param;
        }

        public IQueryable<VendorPaymentList> GetVendorPayment(VendorPaymentReq vendorPaymentReq)
        {
            var param = BuildVendorPaymentParam(vendorPaymentReq);

            return DbContext.VendorPaymentList.FromSqlRaw("[dbo].[VendorPayment_GetAllList] @Pageno,@Pagesize,@StartDate,@EndDate,@PayeeId,@Search,@FromAccount,@PaymentMethod,@Filterby,@IsCount", param);
        }

        private static object[] BuildVendorPaymentParam(VendorPaymentReq vendorPaymentReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", vendorPaymentReq.Pageno),

                new SqlParameter("@Pagesize", vendorPaymentReq.Pagesize),

                vendorPaymentReq.StartDate.HasValue ? new SqlParameter("@StartDate", vendorPaymentReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                vendorPaymentReq.EndDate.HasValue ? new SqlParameter("@EndDate", vendorPaymentReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                vendorPaymentReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", vendorPaymentReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(vendorPaymentReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", vendorPaymentReq.Search),

                string.IsNullOrEmpty(vendorPaymentReq.FromAccount) ? new SqlParameter("@FromAccount", DBNull.Value) : new SqlParameter("@FromAccount", vendorPaymentReq.FromAccount),

                string.IsNullOrEmpty(vendorPaymentReq.PaymentMethod) ? new SqlParameter("@PaymentMethod", DBNull.Value) : new SqlParameter("@PaymentMethod", vendorPaymentReq.PaymentMethod),

                string.IsNullOrEmpty(vendorPaymentReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", vendorPaymentReq.Filterby),
                new SqlParameter("@IsCount", vendorPaymentReq.IsCount),
            };

            return param;
        }
    }
}
