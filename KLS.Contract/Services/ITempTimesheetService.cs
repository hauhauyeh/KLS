using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempTimesheetService
    {
        IEnumerable<TempTimesheet>? GetTempTimesheetList(int timesheetId);

        TempTimesheet GetById(int tempId);

        TempTimesheet CreateTempTimesheet(TempTimesheet tempTimesheet);

        TempTimesheet UpdateTempTimesheet(TempTimesheet tempTimesheet);

        void DeleteTempTimesheet(int tempId);
    }
}
