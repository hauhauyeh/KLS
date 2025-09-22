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
                           IsInactive = act.IsInactive,
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
                IsInactive = x.IsInactive,
                ChildAccounts = BuildTree(accounts, x.AccountId)
            });
        }

        public Account? GetById(int accountId)
        {
            return Uow.Accounts.GetById(accountId);
        }

        public Account? GetByAcctName(string acctname)
        {
            return Uow.Accounts.Find(c => c.AccountName == acctname && c.IsInactive == false).FirstOrDefault();
        }

        public Account? GetByAcctCode(string acctcode)
        {
            return Uow.Accounts.Find(c => c.AccountCode == acctcode && c.IsInactive == false).FirstOrDefault();
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
            existing.AccountDesc = chartOfAccount.AccountDesc;
            existing.IsAccountDebit = chartOfAccount.IsAccountDebit;
            existing.IsInactive = chartOfAccount.IsInactive;
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
            var account = GetByAcctCode(search);

            if (account == null)
                account = GetByAcctName(search);

            return account;
        }

        public IEnumerable<AccountDTO>? SearchAccount(string term)
        {
            return Uow.Accounts.SearchAccount(term).ToList();
        }

        public IEnumerable<AccountDTO>? GetBankCashAccounts()
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
                             IsInactive = a.IsInactive
                         };

            return result.ToList();
        }

        public IEnumerable<AccountDTO>? GetBankCashCCAccounts()
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
                             IsInactive = a.IsInactive
                         };

            return result.ToList();
        }
    }
}
