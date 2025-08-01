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
    public class TempGeneralJournalRepository : KLSRepository<TempGeneralJournal>, ITempGeneralJournalRepository
    {
        public TempGeneralJournalRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<TempGeneralJournal> GetTempGeneralJournalDetails(int gjId, int employeeId, int? tempGJId)
        {
            var EmployeeIdParam = new SqlParameter("@EmployeeId", employeeId);

            var GJIdParam = new SqlParameter("@GJId", gjId);

            var TempGJIdParam = tempGJId.HasValue ? new SqlParameter("@TempGJId", tempGJId) : new SqlParameter("@TempGJId", DBNull.Value);

            return DbContext.TempGeneralJournals.FromSqlRaw("[TempGeneralJournals_GetList] @EmployeeId,@GJId,@TempGJId", EmployeeIdParam, GJIdParam, TempGJIdParam);
        }
    }
}
