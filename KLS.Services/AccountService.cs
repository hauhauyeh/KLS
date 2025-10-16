using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.AspNetCore.OutputCaching;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class AccountService : BaseService, Interfaces.IAccountService
    {
        public AccountService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<AccountTree> GetAccountsTree()
        {
            var category = Uow.AccountTypes.GetAll();
            var accounts = Uow.Accounts.GetAll();

            var lst = (from act in accounts
                       join cat in category on act.AccountTypeId equals cat.AccountTypeId
                       orderby cat.CatNumber, cat.CatName
                       select new AccountTree
                       {
                           CatName = cat.CatName,
                           TypeName = cat.TypeName,
                           AccountId = act.AccountId,
                           AccountCode = act.AccountCode,
                           AccountName = act.AccountName,
                           Inactive = act.Inactive,
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
                ChildAccounts = BuildTree(accounts, x.AccountId)
            });
        }

        public Account? GetById(int accountId)
        {
            return Uow.Accounts.GetById(accountId);
        }

        public Account? GetByAcctName(string acctname)
        {
            return Uow.Accounts.Find(c => c.AccountName == acctname && c.Inactive == false).FirstOrDefault();
        }

        public Account? GetByAccountCode(string accountCode)
        {
            return Uow.Accounts.Find(c => c.AccountCode == accountCode && c.Inactive == false).FirstOrDefault();
        }

        public Account? GetByAcctId(int acctId)
        {
            return Uow.Accounts.Find(c => c.AccountId == acctId && c.Inactive == false).FirstOrDefault();
        }

        public bool AcctNameExists(Account account)
        {
            return Uow.Accounts.Exists(c => c.AccountName.ToLower() == account.AccountName.ToLower() && c.AccountId != account.AccountId);
        }

        public bool AcctCodeExists(Account account)
        {
            return Uow.Accounts.Exists(c => c.AccountCode.ToLower() == account.AccountCode.ToLower() && c.AccountId != account.AccountId);
        }

        public Account CreateAccount(Account chartOfAccount)
        {
            Uow.Accounts.Add(chartOfAccount);
            Uow.Commit();

            return chartOfAccount;
        }

        public Account? UpdateAccount(Account chartOfAccount)
        {
            var existing = GetById(chartOfAccount.AccountId);

            if (existing == null)
                return null;

            existing.AccountTypeId = chartOfAccount.AccountTypeId;
            existing.AccountName = chartOfAccount.AccountName;
            existing.Description = chartOfAccount.Description;
            existing.IsAccountDebit = chartOfAccount.IsAccountDebit;
            existing.Inactive = chartOfAccount.Inactive;
            existing.UpdatedAt = DateTime.UtcNow;

            if (!existing.IsDefaultAccount)
                existing.AccountCode = chartOfAccount.AccountCode;

            Uow.Accounts.Update(existing);
            Uow.Commit();

            return existing;
        }

        public void DeleteAccount(int id)
        {
            Uow.Accounts.RemoveById(id);
            Uow.Commit();
        }

        public Account? CheckAccount(string search)
        {
            //var account = GetByAcctId(search);

            //if (account == null)
            //    account = GetByAcctName(search);

            Account? account = null;

            if (int.TryParse(search, out int acctId))
                account = GetByAcctId(acctId);

            if (account == null)
                account = GetByAccountCode(search);

            if (account == null)
                account = GetByAcctName(search);

            return account;
        }

        public ICollection<AccountDTO>? SearchAccount(string term)
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
                             CatName = at.CatName,
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
                             CatName = at.CatName,
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
                             CatName = at.CatName,
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
                             CatName = at.CatName,
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
                             CatName = at.CatName,
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
    }
}
