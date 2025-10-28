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

        ICollection<AccountDTO>? SearchAccount(string term);

        ICollection<AccountDTO>? GetBankAccounts();

        ICollection<AccountDTO>? GetCashAccounts();

        ICollection<AccountDTO>? GetBankCashAccounts();

        ICollection<AccountDTO>? GetBankCashCCAccounts();

        ICollection<AccountDTO>? GetByPaymentMethod(string pmtMethod);

        ICollection<AccountDTO>? GetACEAccounts();
    }
}
