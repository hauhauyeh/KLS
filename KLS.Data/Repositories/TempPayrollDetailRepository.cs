using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Data.Repositories;
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
    public class TempPayrollDetailRepository : KLSRepository<TempPayrollDetail>, ITempPayrollDetailRepository
    {
        public TempPayrollDetailRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public void UpdateTempPayroll(TempPayrollDetail tempPayroll)
        {
            var TempPayrollIdParam = new SqlParameter("@TempPayrollId", tempPayroll.TempPayrollId);

            var IsAppliedParam = new SqlParameter("@IsApplied", tempPayroll.IsApplied);

            var TotalHourParam = (tempPayroll.TotalHour.HasValue) ? new SqlParameter("@TotalHour", tempPayroll.TotalHour) : new SqlParameter("@TotalHour", DBNull.Value);

            var RegularHourParam = (tempPayroll.RegularHour.HasValue) ? new SqlParameter("@RegularHour", tempPayroll.RegularHour) : new SqlParameter("@RegularHour", DBNull.Value);

            var OvertimeHourParam = (tempPayroll.OvertimeHour.HasValue) ? new SqlParameter("@OvertimeHour", tempPayroll.OvertimeHour) : new SqlParameter("@OvertimeHour", DBNull.Value);

            var IsTotalHourChangeParam = new SqlParameter("@IsTotalHourChange", tempPayroll.IsTotalHourChange);

            var IsRegularHourChangeParam = new SqlParameter("@IsRegularHourChange", tempPayroll.IsRegularHourChange);

            var IsOTHourChangeParam = new SqlParameter("@IsOTHourChange", tempPayroll.IsOTHourChange);

            var RateParam = (tempPayroll.Rate.HasValue) ? new SqlParameter("@Rate", tempPayroll.Rate) : new SqlParameter("@Rate", DBNull.Value);

            var RegularWageParam = (tempPayroll.RegularWage.HasValue) ? new SqlParameter("@RegularWage", tempPayroll.RegularWage) : new SqlParameter("@RegularWage", DBNull.Value);

            var AddOvertimeParam = (tempPayroll.AddOvertime.HasValue) ? new SqlParameter("@AddOvertime", tempPayroll.AddOvertime) : new SqlParameter("@AddOvertime", DBNull.Value);

            var AddCommissionParam = (tempPayroll.AddCommission.HasValue) ? new SqlParameter("@AddCommission", tempPayroll.AddCommission) : new SqlParameter("@AddCommission", DBNull.Value);

            var PreTax401KParam = (tempPayroll.PreTax401K.HasValue) ? new SqlParameter("@PreTax401K", tempPayroll.PreTax401K) : new SqlParameter("@PreTax401K", DBNull.Value);

            var PreTaxHealthInsParam = (tempPayroll.PreTaxHealthIns.HasValue) ? new SqlParameter("@PreTaxHealthIns", tempPayroll.PreTaxHealthIns) : new SqlParameter("@PreTaxHealthIns", DBNull.Value);

            var PreTaxVisionInsParam = (tempPayroll.PreTaxVisionIns.HasValue) ? new SqlParameter("@PreTaxVisionIns", tempPayroll.PreTaxVisionIns) : new SqlParameter("@PreTaxVisionIns", DBNull.Value);

            var PreTaxDentalInsParam = (tempPayroll.PreTaxDentalIns.HasValue) ? new SqlParameter("@PreTaxDentalIns", tempPayroll.PreTaxDentalIns) : new SqlParameter("@PreTaxDentalIns", DBNull.Value);

            var ChildSup1Param = (tempPayroll.ChildSup1.HasValue) ? new SqlParameter("@ChildSup1", tempPayroll.ChildSup1) : new SqlParameter("@ChildSup1", DBNull.Value);

            var ChildSup2Param = (tempPayroll.ChildSup2.HasValue) ? new SqlParameter("@ChildSup2", tempPayroll.ChildSup2) : new SqlParameter("@ChildSup2", DBNull.Value);

            var GarnishmentParam = (tempPayroll.Garnishment.HasValue) ? new SqlParameter("@Garnishment", tempPayroll.Garnishment) : new SqlParameter("@Garnishment", DBNull.Value);

            var LoanRepaymentParam = (tempPayroll.LoanRepayment.HasValue) ? new SqlParameter("@LoanRepayment", tempPayroll.LoanRepayment) : new SqlParameter("@LoanRepayment", DBNull.Value);

            var VendorPmtNumParam = new SqlParameter("@VendorPaymentId", tempPayroll.VendorPaymentId);

            var PayOptionParam = new SqlParameter("@PayOption", tempPayroll.PayOption);

            var PayDateParam = tempPayroll.PayDate != default ? new SqlParameter("@PayDate", tempPayroll.PayDate) : new SqlParameter("@PayDate", DBNull.Value);

            var IsEmpFWHChangeParam = new SqlParameter("@IsEmpFWHChange", tempPayroll.IsEmpFWHChange);

            var EmpFWHParam = (tempPayroll.EmpFWH.HasValue) ? new SqlParameter("@EFWH", tempPayroll.EmpFWH) : new SqlParameter("@EFWH", DBNull.Value);

            var IsEmpOASDIChangeParam = new SqlParameter("@IsEmpOASDIChange", tempPayroll.IsEmpOASDIChange);

            var EmpOASDIParam = (tempPayroll.EmpOASDI.HasValue) ? new SqlParameter("@EOASDI", tempPayroll.EmpOASDI) : new SqlParameter("@EOASDI", DBNull.Value);

            var IsEmpHIChangeParam = new SqlParameter("@IsEmpHIChange", tempPayroll.IsEmpHIChange);

            var EmpHIParam = (tempPayroll.EmpHI.HasValue) ? new SqlParameter("@EHI", tempPayroll.EmpHI) : new SqlParameter("@EHI", DBNull.Value);

            var IsCOASDIChangeParam = new SqlParameter("@IsCOASDIChange", tempPayroll.IsCOASDIChange);

            var CompanyOASDIParam = (tempPayroll.CompanyOASDI.HasValue) ? new SqlParameter("@COASDI", tempPayroll.CompanyOASDI) : new SqlParameter("@COASDI", DBNull.Value);

            var IsCHIChangeParam = new SqlParameter("@IsCHIChange", tempPayroll.IsCHIChange);

            var CompanyHIParam = tempPayroll.CompanyHI.HasValue ? new SqlParameter("@CHI", tempPayroll.CompanyHI) : new SqlParameter("@CHI", DBNull.Value);

            var IsCFUTAChangeParam = new SqlParameter("@IsCFUTAChange", tempPayroll.IsCFUTAChange);

            var CompanyFUTAParam = tempPayroll.CompanyFUTA.HasValue ? new SqlParameter("@CFUTA", tempPayroll.CompanyFUTA) : new SqlParameter("@CFUTA", DBNull.Value);

            var IsCSUTAChangeParam = new SqlParameter("@IsCSUTAChange", tempPayroll.IsCSUTAChange);

            var CompanySUTAParam = tempPayroll.CompanySUTA.HasValue ? new SqlParameter("@CSUTA", tempPayroll.CompanySUTA) : new SqlParameter("@CSUTA", DBNull.Value);

            var CashPayParam = tempPayroll.CashPay.HasValue ? new SqlParameter("@CashPay", tempPayroll.CashPay) : new SqlParameter("@CashPay", DBNull.Value);

            var DeductionParam = tempPayroll.Deduction.HasValue ? new SqlParameter("@Deduction", tempPayroll.Deduction) : new SqlParameter("@Deduction", DBNull.Value);

            var ReimbursementParam = tempPayroll.Reimbursement.HasValue ? new SqlParameter("@Reimbursement", tempPayroll.Reimbursement) : new SqlParameter("@Reimbursement", DBNull.Value);

            DbContext.Database.ExecuteSqlRaw("[TempPayroll_Update] @TempPayrollId,@IsApplied,@TotalHour,@RegularHour,@OvertimeHour,@IsTotalHourChange,@IsRegularHourChange,@IsOTHourChange,@Rate,@RegularWage,@AddOvertime,@AddCommission,@PreTax401K,@PreTaxHealthIns,@PreTaxVisionIns,@PreTaxDentalIns,@ChildSup1,@ChildSup2,@Garnishment,@LoanRepayment,@VendorPaymentId,@PayOption,@PayDate,@IsEmpFWHChange,@EFWH,@IsEmpOASDIChange,@EOASDI,@IsEmpHIChange,@EHI,@IsCOASDIChange,@COASDI,@IsCHIChange,@CHI,@IsCFUTAChange,@CFUTA,@IsCSUTAChange,@CSUTA,@CashPay,@Deduction,@Reimbursement", TempPayrollIdParam, IsAppliedParam, TotalHourParam, RegularHourParam, OvertimeHourParam, IsTotalHourChangeParam, IsRegularHourChangeParam, IsOTHourChangeParam, RateParam, RegularWageParam, AddOvertimeParam, AddCommissionParam, PreTax401KParam, PreTaxHealthInsParam, PreTaxVisionInsParam, PreTaxDentalInsParam, ChildSup1Param, ChildSup2Param, GarnishmentParam, LoanRepaymentParam, VendorPmtNumParam, PayOptionParam, PayDateParam, IsEmpFWHChangeParam, EmpFWHParam, IsEmpOASDIChangeParam, EmpOASDIParam, IsEmpHIChangeParam, EmpHIParam, IsCOASDIChangeParam, CompanyOASDIParam, IsCHIChangeParam, CompanyHIParam, IsCFUTAChangeParam, CompanyFUTAParam, IsCSUTAChangeParam, CompanySUTAParam, CashPayParam, DeductionParam, ReimbursementParam);
        }
    }
}