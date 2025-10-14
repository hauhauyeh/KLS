using KLS.Common;
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
    public class VendorPaymentRepository : KLSRepository<VendorPayment>, IVendorPaymentRepository
    {
        public VendorPaymentRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<CheckRegister> GetCheckRegister(CheckRegisterReq checkRegisterReq)
        {
            var param = BuildCheckRegisterParam(checkRegisterReq);

            return DbContext.CheckRegister.FromSqlRaw("[dbo].[CheckRegister_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@FromAccount,@PaymentMethod,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount", param);
        }

        public int CountAllCheckRegister(CheckRegisterReq checkRegisterReq)
        {
            checkRegisterReq.IsCount = true;
            var param = BuildCheckRegisterParam(checkRegisterReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[CheckRegister_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@FromAccount,@PaymentMethod,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount", param);

            var output = param[12] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildCheckRegisterParam(CheckRegisterReq checkRegisterReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", checkRegisterReq.Pageno),

                new SqlParameter("@Pagesize", checkRegisterReq.Pagesize),

                string.IsNullOrEmpty(checkRegisterReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", checkRegisterReq.Search),

                checkRegisterReq.StartDate.HasValue ? new SqlParameter("@StartDate", checkRegisterReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                checkRegisterReq.EndDate.HasValue ? new SqlParameter("@EndDate", checkRegisterReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                checkRegisterReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", checkRegisterReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(checkRegisterReq.FromAccount) ? new SqlParameter("@FromAccount", DBNull.Value) : new SqlParameter("@FromAccount", checkRegisterReq.FromAccount),

                string.IsNullOrEmpty(checkRegisterReq.PaymentMethod) ? new SqlParameter("@PaymentMethod", DBNull.Value) : new SqlParameter("@PaymentMethod", checkRegisterReq.PaymentMethod),

                string.IsNullOrEmpty(checkRegisterReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", checkRegisterReq.Filterby),

                string.IsNullOrEmpty(checkRegisterReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", checkRegisterReq.SortField),

                string.IsNullOrEmpty(checkRegisterReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", checkRegisterReq.SortOrder),

                new SqlParameter("@IsCount", checkRegisterReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }

        public IQueryable<VendorPaymentList> GetVendorPayment(VendorPaymentReq vendorPaymentReq)
        {
            var param = BuildVendorPaymentParam(vendorPaymentReq);

            return DbContext.VendorPaymentList.FromSqlRaw("[dbo].[VendorPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@FromAccountId,@PaymentMethod,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllVendorPayment(VendorPaymentReq vendorPaymentReq)
        {
            vendorPaymentReq.IsCount = true;
            var param = BuildVendorPaymentParam(vendorPaymentReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[VendorPayment_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@FromAccountId,@PaymentMethod,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[12] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildVendorPaymentParam(VendorPaymentReq vendorPaymentReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", vendorPaymentReq.Pageno),

                new SqlParameter("@Pagesize", vendorPaymentReq.Pagesize),

                string.IsNullOrEmpty(vendorPaymentReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", vendorPaymentReq.Search),

                vendorPaymentReq.StartDate.HasValue ? new SqlParameter("@StartDate", vendorPaymentReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                vendorPaymentReq.EndDate.HasValue ? new SqlParameter("@EndDate", vendorPaymentReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                vendorPaymentReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", vendorPaymentReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                vendorPaymentReq.FromAccountId.HasValue ? new SqlParameter("@FromAccountId", vendorPaymentReq.FromAccountId) : new SqlParameter("@FromAccountId", DBNull.Value),

                string.IsNullOrEmpty(vendorPaymentReq.PaymentMethod) ? new SqlParameter("@PaymentMethod", DBNull.Value) : new SqlParameter("@PaymentMethod", vendorPaymentReq.PaymentMethod),

                string.IsNullOrEmpty(vendorPaymentReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", vendorPaymentReq.Filterby),

                string.IsNullOrEmpty(vendorPaymentReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", vendorPaymentReq.SortField),

                string.IsNullOrEmpty(vendorPaymentReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", vendorPaymentReq.SortOrder),

                new SqlParameter("@IsCount", vendorPaymentReq.IsCount),

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
