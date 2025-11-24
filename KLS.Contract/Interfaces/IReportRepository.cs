using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IReportRepository : IRepository<RPTPoView>
    {
        RPTPo ReportPO(int purchaseId);

        IQueryable<RPTPoDetail> ReportPODetail(int poId);
    }
}
