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
    public class EmpAdvanceRepository : KLSRepository<VendorPayment>, IEmpAdvanceRepository
    {
        public EmpAdvanceRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<EmpAdvance> GetPagedList(EmpAdvanceReq empAdvanceReq)
        {
            var param = BuildParam(empAdvanceReq);

            return DbContext.EmpAdvance.FromSqlRaw("[dbo].[EmpAdvance_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(EmpAdvanceReq empAdvanceReq)
        {
            empAdvanceReq.IsCount = true;
            var param = BuildParam(empAdvanceReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[EmpAdvance_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[9] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildParam(EmpAdvanceReq empAdvanceReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", empAdvanceReq.Pageno),

                new SqlParameter("@Pagesize", empAdvanceReq.Pagesize),

                string.IsNullOrEmpty(empAdvanceReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", empAdvanceReq.Search),

                empAdvanceReq.StartDate.HasValue ? new SqlParameter("@StartDate", empAdvanceReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                empAdvanceReq.EndDate.HasValue ? new SqlParameter("@EndDate", empAdvanceReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                empAdvanceReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", empAdvanceReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(empAdvanceReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", empAdvanceReq.SortField),

                string.IsNullOrEmpty(empAdvanceReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", empAdvanceReq.SortOrder),

                new SqlParameter("@IsCount", empAdvanceReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }

        public int Save(EmpAdvance empAdvance)
        {
            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", empAdvance.VendorPaymentId);

            var PayeeIdParam = new SqlParameter("@PayeeId", empAdvance.PayeeId);

            var PaymentDateParam = new SqlParameter("@PaymentDate", empAdvance.PaymentDate);

            var PaymentMethodParam = new SqlParameter("@PaymentMethod", empAdvance.PaymentMethod);

            var FromAccountIdParam = new SqlParameter("@FromAccountId", empAdvance.FromAccountId);

            var ReferenceIdParam = (!string.IsNullOrEmpty(empAdvance.ReferenceId)) ? new SqlParameter("@ReferenceId", empAdvance.ReferenceId) : new SqlParameter("@ReferenceId", DBNull.Value);

            var PaymentAmountParam = empAdvance.PaymentAmount.HasValue ? new SqlParameter("@PaymentAmount", empAdvance.PaymentAmount) : new SqlParameter("@PaymentAmount", DBNull.Value);

            var NotesParam = (!string.IsNullOrEmpty(empAdvance.Notes)) ? new SqlParameter("@Notes", empAdvance.Notes) : new SqlParameter("@Notes", DBNull.Value);

            var NewVendorPaymentId = new SqlParameter()
            {
                ParameterName = "@NewVendorPaymentId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[EmployeeAdvance_Insert] @VendorPaymentId,@PayeeId,@PaymentDate,@PaymentMethod,@FromAccountId,@ReferenceId,@PaymentAmount,@Notes,@NewVendorPaymentId OUTPUT", VendorPaymentIdParam, PayeeIdParam, PaymentDateParam, PaymentMethodParam, FromAccountIdParam, ReferenceIdParam, PaymentAmountParam, NotesParam, NewVendorPaymentId);

            return Convert.ToInt32(NewVendorPaymentId.Value);
        }
    }
}