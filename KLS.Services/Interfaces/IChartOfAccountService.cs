using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IChartOfAccountService
    {
        ICollection<ChartAccountList> GetAllChartOfAccounts(PagingRequest request);

        ChartOfAccount? GetById(int id);

        List<AcctList> GetActive();

        bool NameExists(ChartOfAccount account);

        bool AcctCodeExists(ChartOfAccount account);

        ChartOfAccount CreateAccount(ChartOfAccount chartOfAccount);

        ChartOfAccount? UpdateAccount(ChartOfAccount chartOfAccount);

        void DeleteAccount(int id);
    }
}
