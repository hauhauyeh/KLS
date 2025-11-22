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
    public class ReportRepository : KLSRepository<RPTPoView>, IReportRepository
    {
        public ReportRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public IQueryable<RPTPo> GetAllReportPO(int poId)
        {
            var POIdParam = new SqlParameter("@POId", poId);

            return DbContext.RPTPo.FromSqlRaw("[dbo].[Report_PO] @POId", POIdParam);
        }

        public IQueryable<RPTPo> GetAllReportPODetail(int poId)
        {
            var POIdParam = new SqlParameter("@POId", poId);

            return DbContext.RPTPo.FromSqlRaw("[dbo].[Report_PODetail] @POId", POIdParam);
        }
    }
}
