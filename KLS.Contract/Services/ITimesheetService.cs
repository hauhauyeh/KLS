using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITimesheetService
    {
        PagingResponse<Timesheet> GetAllTimesheets(TimesheetReq timesheetReq);

        ICollection<TimesheetList>? GetWeeklyTimesheets(TimesheetReq timesheetReq);

        Timesheet GetById(int timesheetId);

        bool ValidateTime(Timesheet timesheet);

        Timesheet SaveTimesheet(Timesheet timesheet);

        void DeleteTimesheet(int timesheetId);

        void InjectTimesheet(int timesheetId, bool isClone);

        PayPeriod? GetPayPeriod();

        PayeeSearch? Validate(string SSNNumber);

        CheckInOut CheckInOut(CheckInOutReq checkInOutReq);
    }
}
