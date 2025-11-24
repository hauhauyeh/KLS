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

        public RPTPo ReportPO(int purchaseId)
        {
            var PurchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);

            //return DbContext.RPTPo.FromSqlRaw("[dbo].[Report_PO] @PurchaseId", PurchaseIdParam)
            //    .ToList().FirstOrDefault();

            var results = DbContext.RPTPo.FromSqlRaw("[dbo].[Report_PO] @PurchaseId", PurchaseIdParam).AsNoTracking().ToList();

            return results.FirstOrDefault();
        }

        public IQueryable<RPTPoDetail> ReportPODetail(int poId)
        {
            var POIdParam = new SqlParameter("@POId", poId);

            return DbContext.RPTPoDetails.FromSqlRaw("[dbo].[Report_PODetail] @POId", POIdParam);
        }
    }
}
