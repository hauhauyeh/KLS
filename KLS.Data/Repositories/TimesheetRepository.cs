using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
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
    public class TimesheetRepository : KLSRepository<Timesheet>, ITimesheetRepository
    {
        public TimesheetRepository(KLSDBContext dbContext) : base(dbContext)
        {
        }

        public int SaveTimesheet(Timesheet timeSheet)
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

        public void InjectTimesheet(int timesheetId, bool isClone)
        {
            var TimesheetIdParam = new SqlParameter("@TimesheetId", timesheetId);

            var IsCloneParam = new SqlParameter("@IsClone", isClone);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[Timesheet_Inject] @TimesheetId,@IsClone,@EmpId", TimesheetIdParam, IsCloneParam, EmpIdParam);
        }
    }
}
