using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.EntityFrameworkCore;
using Org.BouncyCastle.Ocsp;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class AccountService : BaseService, IAccountService
    {
        public AccountService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<AccountList> GetList(string? search)
        {
            var types = Uow.AccountTypes.GetAll();
            var accounts = Uow.Accounts.GetAll();

            if (!string.IsNullOrEmpty(search))
                accounts = accounts.Where(c => c.AccountName.Contains(search) || c.AccountCode.Contains(search));

            // STEP 1: Flat DTO list
            var dtoList =
                (from a in accounts
                 join t in types on a.AccountTypeId equals t.AccountTypeId
                 select new AccountDTO
                 {
                     AccountId = a.AccountId,
                     AccountClass = t.AccountClass,
                     TypeName = t.TypeName,
                     AccountCode = a.AccountCode,
                     AccountName = a.AccountName,
                     Inactive = a.Inactive
                 }).ToList();

            // STEP 2: Group by AccountClass
            var result = dtoList
                .GroupBy(x => x.AccountClass)
                .OrderBy(g => g.Key)
                .Select(g => new AccountList
                {
                    AccountClass = g.Key,
                    Accounts = g.ToList()
                }).ToList();

            return result;
        }

        public IEnumerable<AccountTree> GetAccountsTree()
        {
            var category = Uow.AccountTypes.GetAll();
            var accounts = Uow.Accounts.GetAll();

            var lst = (from act in accounts
                       join cat in category on act.AccountTypeId equals cat.AccountTypeId
                       orderby cat.SortOrder, cat.AccountClass
                       select new AccountTree
                       {
                           //CatName = cat.CatName,
                           TypeName = cat.TypeName,
                           AccountId = act.AccountId,
                           AccountCode = act.AccountCode,
                           AccountName = act.AccountName,
                           Inactive = act.Inactive,
                           IsDefaultAccount = act.IsDefaultAccount,
                           ParentAccountId = act.ParentAccountId
                       }).ToList();

            return BuildTree(lst, null);
        }

        private IEnumerable<AccountTree> BuildTree(IEnumerable<AccountTree> accounts, int? parentId)
        {
            return accounts.Where(x => x.ParentAccountId == parentId).Select(x => new AccountTree
            {
                AccountId = x.AccountId,
                TypeName = x.TypeName,
                CatName = x.CatName,
                AccountCode = x.AccountCode,
                AccountName = x.AccountName,
                ParentAccountId = x.ParentAccountId,
                Inactive = x.Inactive,
                IsDefaultAccount = x.IsDefaultAccount,
                ChildAccounts = BuildTree(accounts, x.AccountId)
            });
        }

        public Account? GetById(int accountId)
        {
            return Uow.Accounts.GetById(accountId);
        }

        public Account? GetByName(string acctName)
        {
            return Uow.Accounts.Find(c => c.AccountName == acctName && c.Inactive == false).Include(c => c.AccountType).FirstOrDefault();
        }

        public Account? GetByCode(string accountCode)
        {
            return Uow.Accounts.Find(c => c.AccountCode == accountCode && c.Inactive == false).Include(c => c.AccountType).FirstOrDefault();
        }

        public Account? GetByAcctId(int acctId)
        {
            return Uow.Accounts.Find(c => c.AccountId == acctId && c.Inactive == false).Include(c => c.AccountType).FirstOrDefault();
        }

        public bool NameExists(Account account)
        {
            return Uow.Accounts.Exists(c => c.AccountName.ToLower() == account.AccountName.ToLower() && c.AccountId != account.AccountId);
        }

        public bool CodeExists(Account account)
        {
            return Uow.Accounts.Exists(c => c.AccountCode.ToLower() == account.AccountCode.ToLower() && c.AccountId != account.AccountId);
        }

        public Account Create(Account account)
        {
            Uow.Accounts.Add(account);
            Uow.Commit();

            return account;
        }

        public Account? Update(Account account)
        {
            var existing = GetById(account.AccountId);

            if (existing == null)
                return null;

            existing.AccountTypeId = account.AccountTypeId;
            existing.AccountName = account.AccountName;
            existing.Description = account.Description;
            existing.IsAccountDebit = account.IsAccountDebit;
            existing.Inactive = account.Inactive;
            existing.UpdatedAt = DateTime.UtcNow;

            if (!existing.IsDefaultAccount)
                existing.AccountCode = account.AccountCode;

            Uow.Accounts.Update(existing);
            Uow.Commit();

            return existing;
        }

        public void Delete(int accountId)
        {
            var account = GetByAcctId(accountId);

            if (account != null && !account.IsDefaultAccount)
            {
                Uow.Accounts.RemoveById(accountId);
                Uow.Commit();
            }
        }

        public Account? CheckAccount(string search)
        {
            Account? account = null;

            if (int.TryParse(search, out int acctId))
                account = GetByAcctId(acctId);

            if (account == null)
                account = GetByCode(search);

            if (account == null)
                account = GetByName(search);

            return account;
        }

        public ICollection<AccountDTO>? Search(string term)
        {
            return Uow.Accounts.SearchAccount(term).ToList();
        }

        public ICollection<AccountDTO>? GetBankAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         join at in Uow.AccountTypes.GetAll()
                             on a.AccountTypeId equals at.AccountTypeId
                         where at.TypeName == "Bank"
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = at.TypeName,
                             //CatName = at.CatName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetCashAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         join at in Uow.AccountTypes.GetAll()
                             on a.AccountTypeId equals at.AccountTypeId
                         where at.TypeName == "Cash"
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = at.TypeName,
                             // CatName = at.CatName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetCCAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         join at in Uow.AccountTypes.GetAll()
                             on a.AccountTypeId equals at.AccountTypeId
                         where at.TypeName == "Credit Card"
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = at.TypeName,
                             //CatName = at.CatName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetBankCashAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         join at in Uow.AccountTypes.GetAll()
                             on a.AccountTypeId equals at.AccountTypeId
                         where at.TypeName == "Bank" || at.TypeName == "Cash"
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = at.TypeName,
                             //CatName = at.CatName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.TypeName).ThenBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetBankCashCCAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         join at in Uow.AccountTypes.GetAll()
                             on a.AccountTypeId equals at.AccountTypeId
                         where at.TypeName == "Bank" || at.TypeName == "Cash" || at.TypeName == "Credit Card"
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = at.TypeName,
                             //CatName = at.CatName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.TypeName).ThenBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetByPaymentMethod(string pmtMethod)
        {
            string normalized = pmtMethod.Trim().Replace(" ", "_").ToUpper();

            if (normalized == EnumHelper.PaymentMethod.CASH.ToString())
                return GetCashAccounts();
            else if (normalized == EnumHelper.PaymentMethod.CREDIT_CARD.ToString())
                return GetCCAccounts();
            else
                return GetBankAccounts();
        }

        public ICollection<AccountDTO>? GetACEAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         join at in Uow.AccountTypes.GetAll()
                             on a.AccountTypeId equals at.AccountTypeId
                         where at.AccountClass != EnumHelper.AccountClass.Income.ToString() && at.AccountClass != EnumHelper.AccountClass.Liability.ToString()
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = at.TypeName,
                             //CatName = at.CatName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.TypeName).ThenBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetExpenseAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         join at in Uow.AccountTypes.GetAll()
                             on a.AccountTypeId equals at.AccountTypeId
                         where at.AccountClass == EnumHelper.AccountClass.Expense.ToString()
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = at.TypeName,
                             //CatName = at.CatName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.TypeName).ThenBy(c => c.AccountName).ToList();
        }
    }
}
