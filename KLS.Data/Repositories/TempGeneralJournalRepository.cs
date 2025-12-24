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
    public class TempGeneralJournalRepository : KLSRepository<TempGeneralJournal>, ITempGeneralJournalRepository
    {
        public TempGeneralJournalRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<TempGeneralJournalList>? GetList(TempGJReq tempGJReq)
        {
            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var GJIdParam = new SqlParameter("@GJId", tempGJReq.GJId);

            var TempGJIdParam = tempGJReq.TempGJId.HasValue ? new SqlParameter("@TempGJId", tempGJReq.TempGJId) : new SqlParameter("@TempGJId", DBNull.Value);

            return DbContext.TempGeneralJournalList.FromSqlRaw("[TempGeneralJournal_GetList] @EmpId,@GJId,@TempGJId", EmpIdParam, GJIdParam, TempGJIdParam);
        }
    }
}
