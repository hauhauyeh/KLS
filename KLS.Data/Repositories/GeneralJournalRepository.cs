using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Data.DataContext;
using KLS.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Org.BouncyCastle.Ocsp;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Data.Repositories
{
    public class GeneralJournalRepository : KLSRepository<GeneralJournal>, IGeneralJournalRepository
    {
        public GeneralJournalRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<GeneralJournal> GetAllGeneralJournals(GJReq gJReq)
        {
            var PagenoParam = new SqlParameter("@Pageno", gJReq.Pageno);

            var PagesizeParam = new SqlParameter("@Pagesize", gJReq.Pagesize);

            var SearchParam = (!string.IsNullOrEmpty(gJReq.Search)) ? new SqlParameter("@Search", gJReq.Search) : new SqlParameter("@Search", DBNull.Value);

            var StartDateParam = gJReq.StartDate.HasValue ? new SqlParameter("@StartDate", gJReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value);

            var EndDateParam = gJReq.EndDate.HasValue ? new SqlParameter("@EndDate", gJReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value);

            var IsCountParam = new SqlParameter("@IsCount", gJReq.IsCount);

            return DbContext.GeneralJournals.FromSqlRaw("[dbo].[GeneralJournal_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@IsCount", PagenoParam, PagesizeParam, SearchParam, StartDateParam, EndDateParam, IsCountParam);
        }

        public int SaveGeneralJournal(GeneralJournal generalJournal)
        {
            var GJIdParam = new SqlParameter("@GJId", generalJournal.GJId);

            var GJDateParam = new SqlParameter("@GjDate", generalJournal.GJDate);

            var NotesParam = (!string.IsNullOrEmpty(generalJournal.Notes)) ? new SqlParameter("@Notes", generalJournal.Notes) : new SqlParameter("@Notes", DBNull.Value);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var NewGJId = new SqlParameter()
            {
                ParameterName = "@NewGJId",
                Direction = System.Data.ParameterDirection.Output,
                SqlDbType = System.Data.SqlDbType.Int
            };

            DbContext.Database.ExecuteSqlRaw("[dbo].[GeneralJournal_Insert] @GJId,@GJDate,@Notes,@EmpId,@NewGJId OUTPUT", GJIdParam, GJDateParam, NotesParam, EmpIdParam, NewGJId);

            return Convert.ToInt32(NewGJId.Value);
        }

        public void InjectGeneralJournal(int gjId)
        {
            var GJIdParam = new SqlParameter("@GJId", gjId);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            DbContext.Database.ExecuteSqlRaw("[dbo].[GeneralJournal_Inject] @GJId,@EmpId", GJIdParam, EmpIdParam);
        }
    }
}
