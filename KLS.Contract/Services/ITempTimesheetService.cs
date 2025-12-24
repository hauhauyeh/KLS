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
        IEnumerable<TempTimesheet>? GetList(int timesheetId);

        TempTimesheet GetById(int tempId);

        TempTimesheet Create(TempTimesheet tempTimesheet);

        TempTimesheet Update(TempTimesheet tempTimesheet);

        void Delete(int tempId);
    }
}
