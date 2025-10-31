using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface ITempPayrollServiceRepository : IRepository<TempPayrollService>
    {
        IQueryable<TempPurchaseItem>? GetTempPurchaseItems(TempPurchaseReq tempReq);
    }
}
