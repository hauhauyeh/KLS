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

        //public IQueryable<BankReconList> GetAllBankRecon()
        //{
        //    var qry = DbContext.BankRecons.AsQueryable();

        //    return Uow.BankRecons.GetAll().OrderBy(b => b.CreatedAt);
        //}

        public List<BankReconList> GetAllBankRecon()
        {
            var qry = Uow.BankRecons.GetAll();

            var acct = from b in qry.Select(c => new { c.AccountCode }).Distinct()
                       join a in Uow.Accounts.GetAll() on b.AccountCode equals a.AccountCode
                       join at in Uow.AccountTypes.GetAll() on a.AccountTypeId equals at.AccountTypeId
                       select new ReconAccount
                       {
                           AccountType = at.TypeName,
                           AccountName = a.AccountName,
                           MaxStatementDate = qry.Where(c => c.AccountCode == b.AccountCode).Max(c => c.StatementDate),
                           BankRecons = qry.Where(c => c.AccountCode == b.AccountCode).OrderByDescending(c => c.StatementDate).ToList()
                       };

            return acct.GroupBy(c => c.AccountType).Select(c => new BankReconList
            {
                AccountType = c.Key,
                ReconAccounts = c.OrderBy(b => b.AccountName).ThenByDescending(b => b.MaxStatementDate).ToList()
            }).ToList();
        }

        public BankRecon GetById(int id)
        {
            return Uow.BankRecons.GetById(id);
        }

        public bool ExistsBankRecon(BankRecon bankRecon)
        {
            return Uow.BankRecons.Exists(c => c.AccountCode == bankRecon.AccountCode && c.StatementDate > bankRecon.StatementDate && bankRecon.BankReconId == 0);
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
                existing.AccountCode = bankRecon.AccountCode;
                existing.StatementDate = bankRecon.StatementDate;
                existing.StatementBalance = bankRecon.StatementBalance;
                existing.SystemBalance = bankRecon.SystemBalance;
                existing.BeginningBalance = bankRecon.BeginningBalance;
                existing.EndingBalance = bankRecon.EndingBalance;
                existing.DifferenceAmount = bankRecon.DifferenceAmount;
                existing.IsReconciled = bankRecon.IsReconciled;
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
