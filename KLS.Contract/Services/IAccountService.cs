using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IAccountService
    {
        //IEnumerable<AccountList> GetList(string? search);

        Account? GetById(int accountId);

        ICollection<AccountDTO>? GetActive();

        bool NameExists(Account account);

        bool CodeExists(Account account);

        Account Create(Account account);

        Account? Update(Account account);

        void Delete(int accountId);

        Account? CheckAccount(string search);

        ICollection<AccountDTO>? Search(string term);

        ICollection<AccountDTO>? GetBankAccounts();

        ICollection<AccountDTO>? GetCashAccounts();

        ICollection<AccountDTO>? GetBankCashAccounts();

        ICollection<AccountDTO>? GetBankCashCCAccounts();

        ICollection<AccountDTO>? GetByPaymentMethod(string pmtMethod);

        ICollection<AccountDTO>? GetACEAccounts();

        ICollection<AccountDTO>? GetExpenseAccounts();
    }
}
