using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IReportRepository : IRepository<RptPOView>
    {
        RptPO ReportPO(int purchaseId);

        IQueryable<RptPODetail> ReportPODetail(int purchaseId);
    }
}
