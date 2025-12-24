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

        public IQueryable<GeneralJournal> GetPagedList(GJReq gJReq)
        {
            var param = BuildGJParam(gJReq);

            return DbContext.GeneralJournals.FromSqlRaw("[dbo].[GeneralJournal_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);
        }

        public int Count(GJReq gJReq)
        {
            gJReq.IsCount = true;
            var param = BuildGJParam(gJReq);

            DbContext.Database.ExecuteSqlRaw("[dbo].[GeneralJournal_GetAllList] @Pageno,@Pagesize,@Search,@StartDate,@EndDate,@SortField,@SortOrder,@IsCount,@TotalCount OUTPUT", param);

            var output = param[8] as SqlParameter;
            return Convert.ToInt32(output.Value);
        }

        public int Save(GeneralJournal generalJournal)
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

        public void Inject(int gjId, bool isClone)
        {
            var GJIdParam = new SqlParameter("@GJId", gjId);

            var EmpIdParam = new SqlParameter("@EmpId", UserContext.EmpId);

            var IsCloneParam = new SqlParameter("@IsClone", isClone);

            DbContext.Database.ExecuteSqlRaw("[dbo].[GeneralJournal_Inject] @GJId,@EmpId,@IsClone", GJIdParam, EmpIdParam, IsCloneParam);
        }

        private static object[] BuildGJParam(GJReq gJReq)
        {
            object[] param = {
                new SqlParameter("@Pageno", gJReq.Pageno),

                new SqlParameter("@Pagesize", gJReq.Pagesize),

                (!string.IsNullOrEmpty(gJReq.Search)) ? new SqlParameter("@Search", gJReq.Search) : new SqlParameter("@Search", DBNull.Value),

                gJReq.StartDate.HasValue ? new SqlParameter("@StartDate", gJReq.StartDate) : new SqlParameter("@StartDate", DBNull.Value),

                gJReq.EndDate.HasValue ? new SqlParameter("@EndDate", gJReq.EndDate) : new SqlParameter("@EndDate", DBNull.Value),

                string.IsNullOrEmpty(gJReq.SortField) ? new SqlParameter("@SortField", DBNull.Value) : new SqlParameter("@SortField", gJReq.SortField),

                string.IsNullOrEmpty(gJReq.SortOrder) ? new SqlParameter("@SortOrder", DBNull.Value) : new SqlParameter("@SortOrder", gJReq.SortOrder),

                new SqlParameter("@IsCount", gJReq.IsCount),

                new SqlParameter()
                {
                    ParameterName = "@TotalCount",
                    Direction = System.Data.ParameterDirection.Output,
                    SqlDbType = System.Data.SqlDbType.Int
                }
            };

            return param;
        }
    }
}
