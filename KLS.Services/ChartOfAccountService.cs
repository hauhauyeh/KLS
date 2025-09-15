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
    public class ChartOfAccountService : BaseService, IChartOfAccountService
    {
        public ChartOfAccountService(IUnitOfWork uow) : base(uow)
        {

        }

        public IEnumerable<ChartAccountTree> GetAccountsTree()
        {
            var category = Uow.ChartOfAccountTypes.GetAll();
            var accounts = Uow.ChartOfAccounts.GetAll();

            var lst = (from act in accounts
                       join cat in category on act.AccountTypeId equals cat.AccountTypeId
                       orderby cat.CatNumber, cat.CatName
                       select new ChartAccountTree
                       {
                           CatName = cat.CatName,
                           AccountType = cat.AccountType,
                           AccountId = act.AccountId,
                           AccountCode = act.AccountCode,
                           AccountName = act.AccountName,
                           IsInactive = act.IsInactive,
                           ParentAccountId = act.ParentAccountId
                       }).ToList();

            return BuildTree(lst, null);
        }

        private IEnumerable<ChartAccountTree> BuildTree(IEnumerable<ChartAccountTree> accounts, int? parentId)
        {
            return accounts.Where(x => x.ParentAccountId == parentId).Select(x => new ChartAccountTree
            {
                AccountId = x.AccountId,
                AccountType = x.AccountType,
                CatName = x.CatName,
                AccountCode = x.AccountCode,
                AccountName = x.AccountName,
                ParentAccountId = x.ParentAccountId,
                IsInactive = x.IsInactive,
                ChildAccounts = BuildTree(accounts, x.AccountId)
            });
        }

        public ChartOfAccount? GetById(int accountId)
        {
            return Uow.ChartOfAccounts.GetById(accountId);
        }

        public ChartOfAccount? GetByAcctName(string acctname)
        {
            return Uow.ChartOfAccounts.Find(c => c.AccountName == acctname && c.IsInactive == false).FirstOrDefault();
        }

        public ChartOfAccount? GetByAcctCode(string acctcode)
        {
            return Uow.ChartOfAccounts.Find(c => c.AccountCode == acctcode && c.IsInactive == false).FirstOrDefault();
        }

        public bool AcctNameExists(ChartOfAccount account)
        {
            return Uow.ChartOfAccounts.Exists(c => c.AccountName.ToLower() == account.AccountName.ToLower() && c.AccountId != account.AccountId);
        }

        public bool AcctCodeExists(ChartOfAccount account)
        {
            return Uow.ChartOfAccounts.Exists(c => c.AccountCode.ToLower() == account.AccountCode.ToLower() && c.AccountId != account.AccountId);
        }

        public ChartOfAccount CreateAccount(ChartOfAccount chartOfAccount)
        {
            Uow.ChartOfAccounts.Add(chartOfAccount);
            Uow.Commit();

            return chartOfAccount;
        }

        public ChartOfAccount? UpdateAccount(ChartOfAccount chartOfAccount)
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

            Uow.ChartOfAccounts.Update(existing);
            Uow.Commit();

            return existing;
        }

        public void DeleteAccount(int id)
        {
            Uow.ChartOfAccounts.RemoveById(id);
            Uow.Commit();
        }

        public ChartOfAccount? CheckAccount(string search)
        {
            var account = GetByAcctCode(search);

            if (account == null)
                account = GetByAcctName(search);

            return account;
        }

        public IEnumerable<AccountDTO>? SearchAccount(string term)
        {
            return Uow.ChartOfAccounts.SearchAccount(term).ToList();
        }

        public IEnumerable<AccountDTO>? GetBankCashAccounts()
        {
            var result = from a in Uow.ChartOfAccounts.GetAll()
                         join at in Uow.ChartOfAccountTypes.GetAll()
                             on a.AccountTypeId equals at.AccountTypeId
                         where at.AccountType == "Bank" || at.AccountType == "Cash"
                         select new AccountDTO
                         {
                             AccountId = a.AccountId,
                             AccountCode = a.AccountCode,
                             AccountName = a.AccountName,
                             AccountType = at.AccountType,
                             CatName = at.CatName,
                             IsInactive = a.IsInactive
                         };

            return result.ToList();
        }
    }
}
