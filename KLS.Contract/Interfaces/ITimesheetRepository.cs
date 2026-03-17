using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ITimesheetRepository : IRepository<Timesheet>
    {
        int Save(Timesheet timeSheet);

        void Inject(int timesheetId, bool isClone);

        PayPeriod? GetPayPeriod();

        List<PayPeriod> GetPayPeriods(int count);

        CheckInOut CheckInOut(CheckInOutReq checkInOutReq);
    }
}
