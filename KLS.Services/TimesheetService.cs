using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
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

        public Timesheet GetById(int timesheetId)
        {
            return Uow.Timesheets.Find(c => c.TimesheetId == timesheetId).Include(c => c.TimeSheetDetails).FirstOrDefault()!;
        }

        public Timesheet SaveTimesheet(Timesheet timeSheet)
        {
            var timesheetId = Uow.Timesheets.SaveTimesheet(timeSheet);

            return GetById(timesheetId);
        }

        public void DeleteTimesheet(int timesheetId)
        {
            Uow.Timesheets.RemoveById(timesheetId);
            Uow.Commit();
        }
    }
}
