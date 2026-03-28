using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class BankReconService : BaseService, IBankReconService
    {
        public BankReconService(IUnitOfWork uow) : base(uow)
        {

        }

        public List<BankReconList> GetList()
        {
            var qry = Uow.BankRecons.GetAll();

            var acct = from b in qry.Select(c => new { c.AccountId }).Distinct()
                       join a in Uow.Accounts.GetAll() on b.AccountId equals a.AccountId
                       select new ReconAccount
                       {
                           AccountType = a.TypeName,
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

        public bool Exists(BankRecon bankRecon)
        {
            return Uow.BankRecons.Exists(c => c.AccountId == bankRecon.AccountId && c.StatementDate > bankRecon.StatementDate && bankRecon.BankReconId == 0);
        }

        public BankRecon Create(BankRecon bankRecon)
        {
            Uow.BankRecons.Add(bankRecon);
            Uow.Commit();

            return bankRecon;
        }

        public BankRecon? Update(BankRecon bankRecon)
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

        public void Delete(int bankReconId)
        {
            Uow.BankRecons.RemoveById(bankReconId);
            Uow.Commit();
        }

        public BankReconBalance GetBalance(int bankReconId)
        {
            return Uow.BankRecons.GetBalance(bankReconId);
        }

        public List<BankTx> GetTx(int bankReconId)
        {
            return Uow.BankRecons.GetTx(bankReconId).ToList();
        }

        public void UpdateBankDate(BankTx bankTx)
        {
            Uow.BankRecons.UpdateBankDate(bankTx);
        }
    }
}
