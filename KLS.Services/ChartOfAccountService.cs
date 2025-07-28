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

        public IEnumerable<ChartAccountList> GetAllAccounts()
        {
            var category = Uow.ChartOfAccountTypes.GetAll();
            var accounts = Uow.ChartOfAccounts.GetAll();

            var lst = from act in accounts
                      join cat in category on act.AccountTypeId equals cat.AccountTypeId
                      orderby cat.CatNumber, cat.CatName
                      select new AccountDTO
                      {
                          CatName = cat.CatName,
                          AccountType = cat.AccountType,
                          AccountId = act.AccountId,
                          AccountCode = act.AccountCode,
                          AccountName = act.AccountName,
                          IsInactive = act.IsInactive
                      };

            return lst.GroupBy(g => g.CatName).Select(c => new ChartAccountList
            {
                CatName = c.Key,
                Accounts = c.ToList()
            });
        }

        public ChartOfAccount? GetById(int accountId)
        {
            return Uow.ChartOfAccounts.GetById(accountId);
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

            existing.AccountName = chartOfAccount.AccountName;
            existing.IsAccountDebit = chartOfAccount.IsAccountDebit;
            existing.AccountDesc = chartOfAccount.AccountDesc;
            existing.IsInactive = chartOfAccount.IsInactive;

            Uow.ChartOfAccounts.Update(existing);
            Uow.Commit();

            return existing;
        }

        public void DeleteAccount(int id)
        {
            Uow.ChartOfAccounts.RemoveById(id);
            Uow.Commit();
        }
    }
}
