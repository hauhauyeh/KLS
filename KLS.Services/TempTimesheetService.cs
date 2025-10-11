using KLS.Common;
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
    public class TempTimesheetService : BaseService, ITempTimesheetService
    {
        public TempTimesheetService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<TempTimesheet>? GetTempTimesheetList(int timesheetId)
        {
            return Uow.TempTimesheets.Find(c => c.EmpId == UserContext.EmpId && c.TimesheetId == timesheetId).Include(c => c.EmpJob);
        }

        public TempTimesheet GetById(int tempId)
        {
            return Uow.TempTimesheets.Find(c => c.TempTimesheetId == tempId).Include(c => c.EmpJob).FirstOrDefault()!;
        }

        public TempTimesheet CreateTempTimesheet(TempTimesheet tempTimesheet)
        {
            //--For timesheeet portal
            //if (tempTimesheet.EmpId == 0)
            tempTimesheet.EmpId = UserContext.EmpId;

            Uow.TempTimesheets.Add(tempTimesheet);
            Uow.Commit();

            return GetById(tempTimesheet.TempTimesheetId);
        }

        public TempTimesheet UpdateTempTimesheet(TempTimesheet tempTimesheet)
        {
            Uow.TempTimesheets.Update(tempTimesheet);
            Uow.Commit();

            return tempTimesheet;
        }

        public void DeleteTempTimesheet(int tempId)
        {
            Uow.TempTimesheets.RemoveById(tempId);
            Uow.Commit();
        }
    }
}
