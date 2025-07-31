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
    public class GeneralJournalRepository : KLSRepository<GeneralJournal>, IGeneralJournalRepository
    {
        public GeneralJournalRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<GeneralJournal> GetAllGeneralJournal(GeneralJournalReq generalJournalReq)
        {
            var PagenoParam = new SqlParameter("@Pageno", generalJournalReq.Pageno);

            var PagesizeParam = new SqlParameter("@Pagesize", generalJournalReq.Pagesize);

            var SearchParam = (!string.IsNullOrEmpty(generalJournalReq.Search)) ? new SqlParameter("@Search", generalJournalReq.Search) : new SqlParameter("@Search", DBNull.Value);

            var GJDateParam = generalJournalReq.GJDate.HasValue ? new SqlParameter("@GJDate", generalJournalReq.GJDate) : new SqlParameter("@GJDate", DBNull.Value);

            var IsCountParam = new SqlParameter("@IsCount", generalJournalReq.IsCount);

            return DbContext.GeneralJournals.FromSqlRaw("[dbo].[GeneralJournal_GetAllList] @Pageno,@Pagesize,@Search,@GJDate,@IsCount", PagenoParam, PagesizeParam, SearchParam, GJDateParam, IsCountParam);
        }
    }
}
