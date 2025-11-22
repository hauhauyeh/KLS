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
        IQueryable<RPTPo> GetAllReportPO(int purchaseId);

        IQueryable<RPTPo> GetAllReportPODetail(int poId);
    }
}
