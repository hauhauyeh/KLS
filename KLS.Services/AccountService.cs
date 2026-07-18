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

        public Account? GetById(int accountId)
        {
            return Uow.Accounts.GetById(accountId);
        }

        public ICollection<AccountDTO>? GetActive()
        {
            var result = from a in Uow.Accounts.GetAll()
                         join at in Uow.AccountCategories.GetAll()
                             on a.AccountCategoryId equals at.AccountCategoryId
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = a.TypeName,
                             Inactive = a.Inactive,
                             ClassName = at.ClassName
                         };

            return result.OrderBy(c => c.ClassName).ThenBy(c => c.AccountName).ToList();
        }

        public Account? GetByName(string acctName)
        {
            return Uow.Accounts.Find(c => c.AccountName == acctName && c.Inactive == false).Include(c => c.AccountCategory).FirstOrDefault();
        }

        public Account? GetByCode(string accountCode)
        {
            return Uow.Accounts.Find(c => c.AccountCode == accountCode && c.Inactive == false).Include(c => c.AccountCategory).FirstOrDefault();
        }

        public Account? GetByAcctId(int acctId)
        {
            return Uow.Accounts.Find(c => c.AccountId == acctId && c.Inactive == false).Include(c => c.AccountCategory).FirstOrDefault();
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
            var category = GetRequiredCategory(account.AccountCategoryId);
            account.TypeName ??= category.CategoryName;

            Uow.Accounts.Add(account);
            Uow.Commit();

            return account;
        }

        public Account? Update(Account account)
        {
            var existing = GetById(account.AccountId);

            if (existing == null)
                return null;

            var category = GetRequiredCategory(existing.AccountCategoryId);

            existing.AccountName = account.AccountName;
            existing.SortOrder = account.SortOrder;
            existing.Description = account.Description;
            existing.IsAccountDebit = account.IsAccountDebit;
            existing.TypeName ??= category.CategoryName;
            existing.Inactive = account.Inactive;
            existing.UpdatedAt = DateTime.UtcNow;

            if (!existing.IsDefaultAccount)
                existing.AccountCode = account.AccountCode;

            Uow.Accounts.Update(existing);
            Uow.Commit();

            return existing;
        }

        private AccountCategory GetRequiredCategory(int categoryId)
        {
            var category = Uow.AccountCategories.GetById(categoryId);
            if (category == null)
                throw new ArgumentException("Account category is required.");

            return category;
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
                         where a.TypeName == "Bank"
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = a.TypeName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetCashAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         where a.TypeName == "Cash"
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = a.TypeName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetCCAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         where a.TypeName == "Credit Card"
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = a.TypeName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetBankCashAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         where a.TypeName == "Bank" || a.TypeName == "Cash"
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = a.TypeName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.TypeName).ThenBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetBankCashCCAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         where a.TypeName == "Bank" || a.TypeName == "Cash" || a.TypeName == "Credit Card"
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = a.TypeName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.TypeName).ThenBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetByPaymentMethod(string pmtMethod)
        {
            string normalized = pmtMethod.Trim().Replace(" ", "_").ToUpper();

            if (normalized == EnumHelper.EnumPaymentMethod.CASH.ToString())
                return GetCashAccounts();
            else if (normalized == EnumHelper.EnumPaymentMethod.CREDIT_CARD.ToString())
                return GetCCAccounts();
            else
                return GetBankAccounts();
        }

        public ICollection<AccountDTO>? GetACEAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         join at in Uow.AccountCategories.GetAll()
                             on a.AccountCategoryId equals at.AccountCategoryId
                         where at.ClassCode != EnumHelper.AccountClass.I.ToString() && at.ClassCode != EnumHelper.AccountClass.L.ToString()
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = a.TypeName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.TypeName).ThenBy(c => c.AccountName).ToList();
        }

        public ICollection<AccountDTO>? GetExpenseAccounts()
        {
            var result = from a in Uow.Accounts.GetAll()
                         join at in Uow.AccountCategories.GetAll()
                             on a.AccountCategoryId equals at.AccountCategoryId
                         where at.ClassCode == EnumHelper.AccountClass.X.ToString()
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             TypeName = a.TypeName,
                             Inactive = a.Inactive
                         };

            return result.OrderBy(c => c.TypeName).ThenBy(c => c.AccountName).ToList();
        }
    }
}
