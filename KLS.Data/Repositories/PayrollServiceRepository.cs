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
    public class PayrollServiceRepository : KLSRepository<PayrollService>, IPayrollServiceRepository
    {
        public PayrollServiceRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<PayrollServiceDTO> GetPagedList(PayrollServiceReq payrollServiceReq)
        {
            var param = BuildParam(payrollServiceReq);

            return DbContext.PayrollServiceDTO.FromSqlRaw("[dbo].[PayrollService_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(PayrollServiceReq payrollServiceReq)
        {
            payrollServiceReq.IsCount = true;
            var param = BuildParam(payrollServiceReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[PayrollService_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[8] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        public int Save(PayrollService service)
        {
            var PayrollServiceIdParam = new SqlParameter("@PayrollServiceId", service.PayrollServiceId);

            var PayrollDateParam = new SqlParameter("@PayrollDate", service.PayrollDate);

            var PayrollStartDateParam = service.PayrollStartDate.HasValue ? new SqlParameter("@PayrollStartDate", service.PayrollStartDate) : new SqlParameter("@PayrollStartDate", DBNull.Value);

            var PayrollEndDateParam = service.PayrollEndDate.HasValue ? new SqlParameter("@PayrollEndDate", service.PayrollEndDate) : new SqlParameter("@PayrollEndDate", DBNull.Value);

            var RegularPayParam = service.RegularPay.HasValue ? new SqlParameter("@RegularPay", service.RegularPay) : new SqlParameter("@RegularPay", DBNull.Value);

            var OverTimePayParam = service.OverTimePay.HasValue ? new SqlParameter("@OverTimePay", service.OverTimePay) : new SqlParameter("@OverTimePay", DBNull.Value);

            var HolidayPayParam = service.HolidayPay.HasValue ? new SqlParameter("@HolidayPay", service.HolidayPay) : new SqlParameter("@HolidayPay", DBNull.Value);

            var VacationPayParam = service.VacationPay.HasValue ? new SqlParameter("@VacationPay", service.VacationPay) : new SqlParameter("@VacationPay", DBNull.Value);

            var EPSLPayParam = service.EPSLPay.HasValue ? new SqlParameter("@EPSLPay", service.EPSLPay) : new SqlParameter("@EPSLPay", DBNull.Value);

            var OtherPayParam = service.OtherPay.HasValue ? new SqlParameter("@OtherPay", service.OtherPay) : new SqlParameter("@OtherPay", DBNull.Value);

            var GrossPayParam = service.GrossPay.HasValue ? new SqlParameter("@GrossPay", service.GrossPay) : new SqlParameter("@GrossPay", DBNull.Value);

            var CommissionParam = service.Commission.HasValue ? new SqlParameter("@Commission", service.Commission) : new SqlParameter("@Commission", DBNull.Value);

            var C401KParam = service.C401K.HasValue ? new SqlParameter("@C401K", service.C401K) : new SqlParameter("@C401K", DBNull.Value);

            var E401KParam = service.E401K.HasValue ? new SqlParameter("@E401K", service.E401K) : new SqlParameter("@E401K", DBNull.Value);

            var E401KLoanParam = service.E401KLoan.HasValue ? new SqlParameter("@E401KLoan", service.E401KLoan) : new SqlParameter("@E401KLoan", DBNull.Value);

            var CHealthInsParam = service.CHealthIns.HasValue ? new SqlParameter("@CHealthIns", service.CHealthIns) : new SqlParameter("@CHealthIns", DBNull.Value);

            var EHealthInsParam = service.EHealthIns.HasValue ? new SqlParameter("@EHealthIns", service.EHealthIns) : new SqlParameter("@EHealthIns", DBNull.Value);

            var CVisionInsParam = service.CVisionIns.HasValue ? new SqlParameter("@CVisionIns", service.CVisionIns) : new SqlParameter("@CVisionIns", DBNull.Value);

            var EVisionInsParam = service.EVisionIns.HasValue ? new SqlParameter("@EVisionIns", service.EVisionIns) : new SqlParameter("@EVisionIns", DBNull.Value);

            var CDentalInsParam = service.CDentalIns.HasValue ? new SqlParameter("@CDentalIns", service.CDentalIns) : new SqlParameter("@CDentalIns", DBNull.Value);

            var EDentalInsParam = service.EDentalIns.HasValue ? new SqlParameter("@EDentalIns", service.EDentalIns) : new SqlParameter("@EDentalIns", DBNull.Value);

            var ChildSupStateParam = service.ChildSupState.HasValue ? new SqlParameter("@ChildSupState", service.ChildSupState) : new SqlParameter("@ChildSupState", DBNull.Value);

            var ChildSupOutStateParam = service.ChildSupOutState.HasValue ? new SqlParameter("@ChildSupOutState", service.ChildSupOutState) : new SqlParameter("@ChildSupOutState", DBNull.Value);

            var GarnishmentParam = service.Garnishment.HasValue ? new SqlParameter("@Garnishment", service.Garnishment) : new SqlParameter("@Garnishment", DBNull.Value);

            var COASDIParam = service.COASDI.HasValue ? new SqlParameter("@COASDI", service.COASDI) : new SqlParameter("@COASDI", DBNull.Value);

            var EOASDIParam = service.EOASDI.HasValue ? new SqlParameter("@EOASDI", service.EOASDI) : new SqlParameter("@EOASDI", DBNull.Value);

            var CHIParam = service.CHI.HasValue ? new SqlParameter("@CHI", service.CHI) : new SqlParameter("@CHI", DBNull.Value);

            var EHIParam = service.EHI.HasValue ? new SqlParameter("@EHI", service.EHI) : new SqlParameter("@EHI", DBNull.Value);

            var EFWHParam = service.EFWH.HasValue ? new SqlParameter("@EFWH", service.EFWH) : new SqlParameter("@EFWH", DBNull.Value);

            var CFUTAParam = service.CFUTA.HasValue ? new SqlParameter("@CFUTA", service.CFUTA) : new SqlParameter("@CFUTA", DBNull.Value);

            var CSUTAParam = service.CSUTA.HasValue ? new SqlParameter("@CSUTA", service.CSUTA) : new SqlParameter("@CSUTA", DBNull.Value);

            var UniformParam = service.Uniform.HasValue ? new SqlParameter("@Uniform", service.Uniform) : new SqlParameter("@Uniform", DBNull.Value);

            var ChildSupAnnualFeeParam = service.ChildSupAnnualFee.HasValue ? new SqlParameter("@ChildSupAnnualFee", service.ChildSupAnnualFee) : new SqlParameter("@ChildSupAnnualFee", DBNull.Value);

            var LoanParam = service.Loan.HasValue ? new SqlParameter("@Loan", service.Loan) : new SqlParameter("@Loan", DBNull.Value);

            var PayrollChargeParam = service.PayrollCharge.HasValue ? new SqlParameter("@PayrollCharge", service.PayrollCharge) : new SqlParameter("@PayrollCharge", DBNull.Value);

            var NetPayParam = service.NetPay.HasValue ? new SqlParameter("@NetPay", service.NetPay) : new SqlParameter("@NetPay", DBNull.Value);

            var FromAccountIdParam = new SqlParameter("@FromAccountId", service.FromAccountId);

            var DirectDepositParam = service.DirectDeposit.HasValue ? new SqlParameter("@DirectDeposit", service.DirectDeposit) : new SqlParameter("@DirectDeposit", DBNull.Value);

            var CheckPayParam = service.CheckPay.HasValue ? new SqlParameter("@CheckPay", service.CheckPay) : new SqlParameter("@CheckPay", DBNull.Value);

            var EPSLCreditParam = service.EPSLCredit.HasValue ? new SqlParameter("@EPSLCredit", service.EPSLCredit) : new SqlParameter("@EPSLCredit", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var NewPayrollServiceId = new SqlParameter()
            {
                ParameterName = "@NewPayrollServiceId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[PayrollService_Insert] @PayrollServiceId,@PayrollDate,@PayrollStartDate,@PayrollEndDate,@RegularPay,@OverTimePay,@HolidayPay,@VacationPay,@EPSLPay,@OtherPay,@GrossPay,@Commission,@C401K,@E401K,@E401KLoan,@CHealthIns,@EHealthIns,@CVisionIns,@EVisionIns,@CDentalIns,@EDentalIns,@ChildSupState,@ChildSupOutState,@Garnishment,@COASDI,@EOASDI,@CHI,@EHI,@EFWH,@CFUTA,@CSUTA,@Uniform,@ChildSupAnnualFee,@Loan,@PayrollCharge,@NetPay,@FromAccountId,@DirectDeposit,@CheckPay,@EPSLCredit,@EmpId,@NewPayrollServiceId OUTPUT", PayrollServiceIdParam, PayrollDateParam, PayrollStartDateParam, PayrollEndDateParam, RegularPayParam, OverTimePayParam, HolidayPayParam, VacationPayParam, EPSLPayParam, OtherPayParam, GrossPayParam, CommissionParam, C401KParam, E401KParam, E401KLoanParam, CHealthInsParam, EHealthInsParam, CVisionInsParam, EVisionInsParam, CDentalInsParam, EDentalInsParam, ChildSupStateParam, ChildSupOutStateParam, GarnishmentParam, COASDIParam, EOASDIParam, CHIParam, EHIParam, EFWHParam, CFUTAParam, CSUTAParam, UniformParam, ChildSupAnnualFeeParam, LoanParam, PayrollChargeParam, NetPayParam, FromAccountIdParam, DirectDepositParam, CheckPayParam, EPSLCreditParam, EmpIdParam, NewPayrollServiceId);

            return Convert.ToInt32(NewPayrollServiceId.Value);
        }

        public void Inject(int payrollServiceId, bool isClone)
        {
            var PayrollServiceIdParam = new SqlParameter("@PayrollServiceId", payrollServiceId);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var IsCloneParam = new SqlParameter("@IsClone", isClone);

            DbContext.Database.ExecuteSqlRaw("[dbo].[PayrollService_Inject] @PayrollServiceId,@EmpId,@IsClone", PayrollServiceIdParam, EmpIdParam, IsCloneParam);
        }

        public void InjectEmployee()
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[PayrollService_InjectEmp] @EmpId", EmpIdParam);
        }

        private static object[] BuildParam(PayrollServiceReq payrollServiceReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", payrollServiceReq.Pageno),

                new SqlParameter("@Pagesize", payrollServiceReq.Pagesize),

                string.IsNullOrEmpty(payrollServiceReq.Search) ? new SqlParameter("@Search", DBNull.Value) : new SqlParameter("@Search", payrollServiceReq.Search),

                payrollServiceReq.StartDate.HasValue ? new SqlParameter("@StartDate", payrollServiceReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                payrollServiceReq.EndDate.HasValue ? new SqlParameter("@EndDate", payrollServiceReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                string.IsNullOrEmpty(payrollServiceReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", payrollServiceReq.SortField),

                string.IsNullOrEmpty(payrollServiceReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", payrollServiceReq.SortOrder),

                new SqlParameter("@IsCount", payrollServiceReq.IsCount),

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