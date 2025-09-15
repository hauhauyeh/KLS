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
        IQueryable<AccountDTO> SearchAccount(string term);

        CreditDebitAmount GetCrDeAmount(string accountCode, decimal? amount);
    }
}