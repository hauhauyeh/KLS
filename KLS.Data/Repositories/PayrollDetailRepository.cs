using Azure;
using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Data.Repositories;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Org.BouncyCastle.Ocsp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class PayrollDetailRepository : KLSRepository<PayrollDetail>, IPayrollDetailRepository
    {
        public PayrollDetailRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<PayrollList> GetAllPayrolls(PayrollReq payrollReq)
        {
            var param = BuildPayrollParam(payrollReq);

            return DbContext.PayrollList.FromSqlRaw("[dbo].[Payroll_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int CountAllPayrolls(PayrollReq payrollReq)
        {
            payrollReq.IsCount = true;
            var param = BuildPayrollParam(payrollReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Payroll_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@PayeeId,@Filterby,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[10] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        private static object[] BuildPayrollParam(PayrollReq payrollReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", payrollReq.Pageno),

                new SqlParameter("@Pagesize", payrollReq.Pagesize),

                string.IsNullOrEmpty(payrollReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", payrollReq.Search),

                payrollReq.StartDate.HasValue ? new SqlParameter("@StartDate", payrollReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                payrollReq.EndDate.HasValue ? new SqlParameter("@EndDate", payrollReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                payrollReq.PayeeId.HasValue ? new SqlParameter("@PayeeId", payrollReq.PayeeId) : new SqlParameter("@PayeeId", DBNull.Value),

                string.IsNullOrEmpty(payrollReq.Filterby) ? new SqlParameter("@Filterby", DBNull.Value) : new SqlParameter("@Filterby", payrollReq.Filterby),

                string.IsNullOrEmpty(payrollReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", payrollReq.SortField),

                string.IsNullOrEmpty(payrollReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", payrollReq.SortOrder),

                new SqlParameter("@IsCount", payrollReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }

        public void InjectPayrollEmp(PayrollInjectEmpReq injectEmpReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var PayOptionParam = new SqlParameter("@PayOption", injectEmpReq.PayOption);

            var PayDateParam = new SqlParameter("@PayDate", injectEmpReq.PayDate);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Payroll_InjectEmp] @EmpId,@PayOption,@PayDate", EmpIdParam, PayOptionParam, PayDateParam);
        }

        public void InjectPayroll(int vendorPaymentId)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var VendorPaymentIdParam = new SqlParameter("@VendorPaymentId", vendorPaymentId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Payroll_Inject] @EmpId,@VendorPaymentId", EmpIdParam, VendorPaymentIdParam);
        }

        public ImportPayrollResp ImportPayroll(string excelfile)
        {
            var FilePathParam = String.IsNullOrEmpty(excelfile) ? new SqlParameter("@FilePath", DBNull.Value) : new SqlParameter("@FilePath", excelfile);

            var EmpIdParameter = new SqlParameter("@EmpId", UserContext.EmpId);

            var ImportCountnum = new SqlParameter()
            {
                ParameterName = "@ImportCount",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            var ErrorParam = new SqlParameter()
            {
                ParameterName = "@Error",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.NVarChar,
                Size = 255
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[Payroll_Import] @FilePath,@EmpId,@ImportCount OUTPUT,@Error OUTPUT", FilePathParam, EmpIdParameter, ImportCountnum, ErrorParam);

            var response = new ImportPayrollResp();

            response.ImportCount = ImportCountnum.Value == DBNull.Value ? null : Convert.ToInt32(ImportCountnum.Value);

            response.Error = Convert.ToString(ErrorParam.Value);

            return response;
        }
    }
}