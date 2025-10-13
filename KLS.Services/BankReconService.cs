using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static KLS.Models.BankReconList;

namespace KLS.Services
{
    public class BankReconService : BaseService, IBankReconService
    {
        public BankReconService(IUnitOfWork uow) : base(uow)
        {

        }

        public List<BankReconList> GetAllBankRecon()
        {
            var qry = Uow.BankRecons.GetAll();

            var acct = from b in qry.Select(c => new { c.AccountId }).Distinct()
                       join a in Uow.Accounts.GetAll() on b.AccountId equals a.AccountId
                       join at in Uow.AccountTypes.GetAll() on a.AccountTypeId equals at.AccountTypeId
                       select new ReconAccount
                       {
                           AccountType = at.TypeName,
                           AccountName = a.AccountName,
                           MaxStatementDate = qry.Where(c => c.AccountId == b.AccountId).Max(c => c.StatementDate),
                           BankRecons = qry.Where(c => c.AccountId == b.AccountId).OrderByDescending(c => c.StatementDate).ToList()
                       };

            return acct.GroupBy(c => c.AccountType).Select(c => new BankReconList
            {
                AccountType = c.Key,
                ReconAccounts = c.OrderBy(b => b.AccountName).ThenByDescending(b => b.MaxStatementDate).ToList()
            }).ToList();
        }

        public BankRecon GetById(int bankReconId)
        {
            return Uow.BankRecons.GetById(bankReconId);
        }

        public bool ExistsBankRecon(BankRecon bankRecon)
        {
            return Uow.BankRecons.Exists(c => c.AccountId == bankRecon.AccountId && c.StatementDate > bankRecon.StatementDate && bankRecon.BankReconId == 0);
        }

        public BankRecon CreateBankRecon(BankRecon bankRecon)
        {
            Uow.BankRecons.Add(bankRecon);
            Uow.Commit();

            return bankRecon;
        }

        public BankRecon? UpdateBankRecon(BankRecon bankRecon)
        {
            var existing = GetById(bankRecon.BankReconId);

            if (existing != null)
            {
                existing.AccountId = bankRecon.AccountId;
                existing.StatementDate = bankRecon.StatementDate;
                existing.StatementBalance = bankRecon.StatementBalance;
                existing.BeginningBalance = bankRecon.BeginningBalance;
                existing.Notes = bankRecon.Notes;

                existing.UpdatedAt = DateTime.UtcNow;

                Uow.BankRecons.Update(existing);
                Uow.Commit();
            }

            return existing;
        }

        public void UpdateNotes(BankRecon bankRecon)
        {
            var existing = GetById(bankRecon.BankReconId);

            if (existing != null)
            {
                existing.Notes = bankRecon.Notes;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.BankRecons.Update(existing);
                Uow.Commit();
            }
        }

        public void DeleteBankRecon(int bankReconId)
        {
            Uow.BankRecons.RemoveById(bankReconId);
            Uow.Commit();
        }
    }
}
