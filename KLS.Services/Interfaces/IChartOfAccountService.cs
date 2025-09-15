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
        IEnumerable<ChartAccountTree> GetAccountsTree();

        ChartOfAccount? GetById(int accountId);

        bool AcctNameExists(ChartOfAccount account);

        bool AcctCodeExists(ChartOfAccount account);

        ChartOfAccount CreateAccount(ChartOfAccount account);

        ChartOfAccount? UpdateAccount(ChartOfAccount account);

        void DeleteAccount(int accountId);

        ChartOfAccount? CheckAccount(string search);

        IEnumerable<AccountDTO>? SearchAccount(string term);

        IEnumerable<AccountDTO>? GetBankCashAccounts();
    }
}
