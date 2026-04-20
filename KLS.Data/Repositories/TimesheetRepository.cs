using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class TimesheetRepository : KLSRepository<Timesheet>, ITimesheetRepository
    {
        public TimesheetRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public int Save(Timesheet timeSheet)
        {
            var TimesheetIdParam = new SqlParameter("@TimesheetId", timeSheet.TimesheetId);

            var PayeeIdParam = new SqlParameter("@PayeeId", timeSheet.PayeeId);

            var InTimeParam = new SqlParameter("@InTime", timeSheet.InTime);

            var OutTimeParam = timeSheet.OutTime.HasValue ? new SqlParameter("@OutTime", timeSheet.OutTime) : new SqlParameter("@OutTime", DBNull.Value);

            var NotesParam = (!String.IsNullOrEmpty(timeSheet.Notes)) ? new SqlParameter("@Notes", timeSheet.Notes) : new SqlParameter("@Notes", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var NewTimesheetId = new SqlParameter()
            {
                ParameterName = "@NewTimesheetId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[Timesheet_Insert] @TimesheetId,@PayeeId,@InTime,@OutTime,@Notes,@EmpId,@NewTimesheetId OUTPUT", TimesheetIdParam, PayeeIdParam, InTimeParam, OutTimeParam, NotesParam, EmpIdParam, NewTimesheetId);

            return Convert.ToInt32(NewTimesheetId.Value);
        }

        public void Inject(int timesheetId, bool isClone)
        {
            var TimesheetIdParam = new SqlParameter("@TimesheetId", timesheetId);

            var IsCloneParam = new SqlParameter("@IsClone", isClone);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Timesheet_Inject] @TimesheetId,@IsClone,@EmpId", TimesheetIdParam, IsCloneParam, EmpIdParam);
        }

        public PayPeriod? GetPayPeriod(int? payOption, DateOnly? payDate, string mode = "Previous")
        {
            var parameters = new[]
            {
                new SqlParameter("@PayOption", payOption ?? (object)DBNull.Value),
                new SqlParameter("@PayDate", payDate.HasValue ? payDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value),
                new SqlParameter("@Mode", mode),
                new SqlParameter("@PayrollStartDate", SqlDbType.Date) { Direction = ParameterDirection.Output },
                new SqlParameter("@PayrollEndDate", SqlDbType.Date) { Direction = ParameterDirection.Output }
            };

            DbContext.Database.ExecuteSqlRaw(
                "EXEC dbo.Fn_Calc_PayrollDate @PayOption, @PayDate, @Mode, @PayrollStartDate OUTPUT, @PayrollEndDate OUTPUT",
                parameters);

            if (parameters[3].Value == DBNull.Value || parameters[4].Value == DBNull.Value)
                return null;

            return new PayPeriod
            {
                PayrollStartDate = DateOnly.FromDateTime((DateTime)parameters[3].Value),
                PayrollEndDate = DateOnly.FromDateTime((DateTime)parameters[4].Value)
            };
        }

        public List<PayPeriod> GetPayPeriods(int count)
        {
            var periods = new List<PayPeriod>();
            if (count <= 0) return periods;

            var today = DateOnly.FromDateTime(DateTime.Today);

            // 1. Current
            var current = GetPayPeriod(null, today, "Current");
            if (current == null) return periods;

            periods.Add(current);

            // 2. Previous periods
            var referenceDate = current.PayrollStartDate.Value.AddDays(-1);

            while (periods.Count < count)
            {
                var prev = GetPayPeriod(null, referenceDate, "Current");
                if (prev == null) break;

                periods.Add(prev);
                referenceDate = prev.PayrollStartDate.Value.AddDays(-1);
            }

            return periods;
        }

        //public PayPeriod? GetPayPeriod(int? payOption, DateOnly? paymentDate)
        //{
        //    var PayOptionParam = new SqlParameter("@PayOption", payOption.HasValue ? payOption.Value : DBNull.Value);

        //    var PayDateParam = new SqlParameter("@Paydate",
        //        paymentDate.HasValue ? paymentDate.Value : DBNull.Value);

        //    var PayrollStartDate = new SqlParameter()
        //    {
        //        ParameterName = "@PayrollStartDate",
        //        Direction = System.Data.ParameterDirection.Output,
        //        SqlDbType = System.Data.SqlDbType.Date
        //    };

        //    var PayrollEndDate = new SqlParameter()
        //    {
        //        ParameterName = "@PayrollEndDate",
        //        Direction = System.Data.ParameterDirection.Output,
        //        SqlDbType = System.Data.SqlDbType.Date
        //    };

        //    DbContext.Database.ExecuteSqlRaw("[Fn_Calc_PayrollDate] @PayOption,@Paydate,@PayrollStartDate OUTPUT,@PayrollEndDate OUTPUT", PayOptionParam, PayDateParam, PayrollStartDate, PayrollEndDate);

        //    var startDate = PayrollStartDate.Value as DateTime?;
        //    var endDate = PayrollEndDate.Value as DateTime?;

        //    return new PayPeriod
        //    {
        //        PayrollStartDate = DateOnly.FromDateTime(startDate.Value),
        //        PayrollEndDate = DateOnly.FromDateTime(endDate.Value)
        //    };
        //}

        //public List<PayPeriod> GetPayPeriods(int count)
        //{
        //    var periods = new List<PayPeriod>();

        //    // Get current period first, then derive next future period from it
        //    var currentPeriod = GetPayPeriod(null, null);
        //    var currentStart = currentPeriod!.PayrollStartDate!.Value;
        //    var currentEnd = currentPeriod!.PayrollEndDate!.Value;
        //    var periodDays = currentEnd.DayNumber - currentStart.DayNumber; // 6 for weekly, 13 for biweekly

        //    var nextStart = currentEnd.AddDays(1);
        //    var nextEnd = nextStart.AddDays(periodDays);
        //    periods.Add(new PayPeriod
        //    {
        //        PayrollStartDate = nextStart,
        //        PayrollEndDate = nextEnd
        //    });

        //    // Now get current + past periods from the SP
        //    var currentDate = DateTime.Now;

        //    for (int i = 1; i < count; i++)
        //    {
        //        var payOptionParam = new SqlParameter("@Payoption", DBNull.Value);
        //        var payDateParam = new SqlParameter("@Paydate", currentDate);
        //        var payrollStartDate = new SqlParameter()
        //        {
        //            ParameterName = "@PayrollStartDate",
        //            Direction = System.Data.ParameterDirection.Output,
        //            SqlDbType = System.Data.SqlDbType.Date
        //        };
        //        var payrollEndDate = new SqlParameter()
        //        {
        //            ParameterName = "@PayrollEndDate",
        //            Direction = System.Data.ParameterDirection.Output,
        //            SqlDbType = System.Data.SqlDbType.Date
        //        };

        //        DbContext.Database.ExecuteSqlRaw(
        //            "[Fn_Calc_PayrollDate] @Payoption,@Paydate,@PayrollStartDate OUTPUT,@PayrollEndDate OUTPUT",
        //            payOptionParam, payDateParam, payrollStartDate, payrollEndDate);

        //        var start = (DateTime)payrollStartDate.Value;
        //        var end = (DateTime)payrollEndDate.Value;

        //        periods.Add(new PayPeriod
        //        {
        //            PayrollStartDate = DateOnly.FromDateTime(start),
        //            PayrollEndDate = DateOnly.FromDateTime(end)
        //        });

        //        // Step back one day before this period's start to get the previous period
        //        currentDate = start.AddDays(-1);
        //    }

        //    return periods;
        //}

        public CheckInOut CheckInOut(CheckInOutReq checkInOutReq)
        {
            var PayeeIdParam = new SqlParameter("@PayeeId", checkInOutReq.PayeeId);

            var IsDetailSaveParam = new SqlParameter("@IsDetailSave", checkInOutReq.IsDetailSave);

            var IsDetailAddParam = new SqlParameter("@IsDetailAdd", checkInOutReq.IsDetailAdd);

            return DbContext.CheckInOut.FromSqlRaw("[dbo].[Timesheet_CheckInOut] @PayeeId,@IsDetailSave,@IsDetailAdd", PayeeIdParam, IsDetailSaveParam, IsDetailAddParam).ToList().FirstOrDefault();
        }
    }
}
