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
    }
}
