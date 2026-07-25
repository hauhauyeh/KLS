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
        PagingResponse<Timesheet> GetPagedList(TimesheetReq timesheetReq);

        ICollection<TimesheetList>? GetWeeklyTimesheets(TimesheetReq timesheetReq);

        Timesheet GetById(int timesheetId);

        bool ValidateTime(Timesheet timesheet);

        Timesheet Save(Timesheet timesheet);

        void Delete(int timesheetId);

        int BatchDelete(int payeeId, DateOnly? startDate, DateOnly? endDate);

        void Inject(int timesheetId, bool isClone);

        PayPeriod? GetPayPeriod();

        List<PayPeriod> GetPayPeriods(int count);

        PayeeSearch? Validate(string SSNNumber);

        CheckInOut CheckInOut(CheckInOutReq checkInOutReq);
    }
}
