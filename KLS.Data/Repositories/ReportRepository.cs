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
    public class ReportRepository : KLSRepository<RptPOView>, IReportRepository
    {
        public ReportRepository(KLSDBContext dbContext) : base(dbContext)
        {

        }

        public RptPO ReportPO(int purchaseId)
        {
            var PurchaseIdParam = new SqlParameter("@PurchaseId", purchaseId);

            return DbContext.RptPO.FromSqlRaw("[dbo].[Report_PO] @PurchaseId", PurchaseIdParam).AsEnumerable().SingleOrDefault()!;
        }

        public IQueryable<RptPODetail> ReportPODetail(int purchaseId)
        {
            var PurchaseIdParam = new SqlParameter("@purchaseId", purchaseId);

            return DbContext.RptPODetail.FromSqlRaw("[dbo].[Report_PODetail] @purchaseId", PurchaseIdParam);
        }
    }
}
