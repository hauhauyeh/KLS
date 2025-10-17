using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Models.Deposit;
using KLS.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Org.BouncyCastle.Ocsp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TimesheetService : BaseService, ITimesheetService
    {
        public TimesheetService(IUnitOfWork uow) : base(uow)
        {
        }

        public PagingResponse<Timesheet> GetAllTimesheets(TimesheetReq timesheetReq)
        {
            var qry = BuildTimesheetQuery(timesheetReq, includeDetails: false);

            var totalRecords = qry.Count();

            var list = qry
                .Skip(timesheetReq.Pagesize * (timesheetReq.Pageno - 1))
                .Take(timesheetReq.Pagesize)
                .ToList();

            foreach (var timesheet in list)
            {
                var payee = Uow.Payees.GetById(timesheet.PayeeId);

                if (payee != null)
                    timesheet.PayeeName = payee.PayeeName;
            }

            return new PagingResponse<Timesheet>(totalRecords, timesheetReq.Pageno, timesheetReq.Pagesize)
            {
                RowData = list,
            };
        }

        public ICollection<TimesheetList>? GetWeeklyTimesheets(TimesheetReq timesheetReq)
        {
            if (!timesheetReq.StartDate.HasValue)
            {
                var payPeriod = GetPayPeriod();
                timesheetReq.StartDate = payPeriod.PayrollStartDate;
                timesheetReq.EndDate = payPeriod.PayrollEndDate;
            }

            var qry = BuildTimesheetQuery(timesheetReq, includeDetails: true).ToList();

            foreach (var timesheet in qry)
            {
                var payee = Uow.Payees.GetById(timesheet.PayeeId);

                if (payee != null)
                    timesheet.PayeeName = payee.PayeeName;
            }

            return qry.GroupBy(c => new { c.PayeeId, c.PayeeName })
                    .Select(c => new TimesheetList
                    {
                        PayeeId = c.Key.PayeeId,
                        PayeeName = c.Key.PayeeName,
                        TotalHours = c.Aggregate(TimeSpan.Zero, (subtotal, t) => subtotal.Add(t.WorkingHour)).TotalHours,
                        TotalSalary = c.Sum(t => t.TimeSheetDetails.Sum(td => td.ExtTotal)),
                        Timesheets = c.OrderBy(t => t.InTime).ToList()
                    })
                    .OrderBy(c => c.PayeeName)
                    .ToList();
        }

        private IQueryable<Timesheet> BuildTimesheetQuery(TimesheetReq req, bool includeDetails = false)
        {
            var qry = Uow.Timesheets.GetAll();

            if (req.StartDate.HasValue)
                qry = qry.Where(t => DateOnly.FromDateTime(t.InTime) >= req.StartDate.Value);

            if (req.EndDate.HasValue)
                qry = qry.Where(t => DateOnly.FromDateTime(t.InTime) <= req.EndDate.Value);

            if (req.PayeeId.HasValue)
                qry = qry.Where(t => t.PayeeId == req.PayeeId.Value);

            if (includeDetails)
                qry = qry.Include(t => t.TimeSheetDetails)
                         .ThenInclude(td => td.EmpJob);

            // Common ordering
            qry = qry.OrderByDescending(t => t.InTime.Date)
                     .ThenBy(t => t.InTime.TimeOfDay);

            return qry;
        }

        public Timesheet GetById(int timesheetId)
        {
            var timesheet = Uow.Timesheets.Find(c => c.TimesheetId == timesheetId).Include(c => c.TimeSheetDetails).FirstOrDefault()!;

            var payee = Uow.Payees.GetById(timesheet.PayeeId);

            if (payee != null)
                timesheet.PayeeName = payee.PayeeName;

            return timesheet;
        }

        public bool ValidateTime(Timesheet timesheet)
        {
            if (timesheet.OutTime.HasValue)
            {
                if (timesheet.OutTime.Value <= timesheet.InTime)
                    return true;
            }
            return false;
        }

        public Timesheet SaveTimesheet(Timesheet timesheet)
        {
            //convert to utc
            var timezone = UserContext.UserTimezone;

            timesheet.InTime = Utilities.ConvertToUtc(timesheet.InTime, timezone);

            if (timesheet.OutTime.HasValue)
                timesheet.OutTime = Utilities.ConvertToUtc(timesheet.OutTime.Value, timezone);

            var timesheetId = Uow.Timesheets.SaveTimesheet(timesheet);

            return GetById(timesheetId);
        }

        public void DeleteTimesheet(int timesheetId)
        {
            Uow.Timesheets.RemoveById(timesheetId);
            Uow.Commit();
        }

        public void InjectTimesheet(int timesheetId, bool isClone)
        {
            Uow.Timesheets.InjectTimesheet(timesheetId, isClone);
        }

        public PayPeriod? GetPayPeriod()
        {
            return Uow.Timesheets.GetPayPeriod();
        }

        public PayeeSearch? Validate(string SSNNumber)
        {
            var employee = Uow.Employees.Find(c => c.SSN != null && c.SSN.EndsWith(SSNNumber)).FirstOrDefault();

            if (employee == null)
            {
                return null;
            }

            var payee = new PayeeSearch
            {
                PayeeId = employee.PayeeId,
                PayeeName = employee.FirstName,
            };

            return payee;
        }

        public CheckInOut CheckInOut(CheckInOutReq checkInOutReq)
        {
            return Uow.Timesheets.CheckInOut(checkInOutReq);
        }
    }
}
