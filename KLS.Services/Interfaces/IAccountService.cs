using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IAccountService
    {
        IEnumerable<AccountTree> GetAccountsTree();

        Account? GetById(int accountId);

        bool AcctNameExists(Account account);

        bool AcctCodeExists(Account account);

        Account CreateAccount(Account account);

        Account? UpdateAccount(Account account);

        void DeleteAccount(int accountId);

        Account? CheckAccount(string search);

        IEnumerable<AccountDTO>? SearchAccount(string term);

        IEnumerable<AccountDTO>? GetBankCashAccounts();

        IEnumerable<AccountDTO>? GetBankAccounts();

        IEnumerable<AccountDTO>? GetBankCashCCAccounts();
    }
}
