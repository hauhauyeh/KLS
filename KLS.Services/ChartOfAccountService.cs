using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
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

        public ICollection<ChartAccountList> GetAllChartOfAccounts(PagingRequest request)
        {
            return Uow.ChartOfAccounts.GetAllChartOfAccounts(request);
        }

        public ChartOfAccount? GetById(int id)
        {
            return Uow.ChartOfAccounts.GetById(id);
        }

        public List<AcctList> GetAll()
        {
            var accounts = Uow.ChartOfAccounts.GetAll().ToList();
            var accountTypes = Uow.ChartOfAccountTypes.GetAll().ToList();

            return (from c in accounts
                    join ct in accountTypes on c.AccountTypeId equals ct.AccountTypeId
                    orderby ct.TypeNumber, c.AccountName
                    select new AcctList()
                    {
                        AcctTypeId = c.AccountTypeId,
                        AcctCode = c.AccountCode,
                        AcctName = c.AccountName,
                        Inactive = c.Inactive
                    }).ToList();
        }

        public List<AcctList> GetActive()
        {
            return GetAll().Where(c => c.Inactive == false).ToList();
        }

        public bool NameExists(ChartOfAccount account)
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
            existing.IsAccountCR = chartOfAccount.IsAccountCR;
            existing.AccountDesc = chartOfAccount.AccountDesc;
            existing.Inactive = chartOfAccount.Inactive;

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
