using KLS.Contract.Interfaces;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IChartOfAccountRepository : IRepository<ChartOfAccount>
    {
        ICollection<ChartAccountList> GetAllChartOfAccounts(PagingRequest request);
    }
}