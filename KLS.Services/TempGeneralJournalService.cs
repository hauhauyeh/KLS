using KLS.Common;
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
    public class TempGeneralJournalService : BaseService, ITempGeneralJournalService
    {
        private IAccountService _accountService;

        public TempGeneralJournalService(IUnitOfWork uow, IAccountService AccountService) : base(uow)
        {
            _accountService = AccountService;
        }

        public IEnumerable<TempGeneralJournalList>? GetList(TempGJReq tempGJReq)
        {
            return Uow.TempGeneralJournals.GetList(tempGJReq)?.ToList();
        }

        public TempGeneralJournalList? GetListById(TempGeneralJournal tempGJ)
        {
            var tempGJReq = new TempGJReq
            {
                TempGJId = tempGJ.TempGJId,
                GJId = tempGJ.GJId
            };

            return GetList(tempGJReq)?.FirstOrDefault();
        }

        public TempGeneralJournal GetById(int tempGJId)
        {
            return Uow.TempGeneralJournals.GetById(tempGJId);
        }

        public TempGeneralJournalList Create(TempGeneralJournal tempGJ)
        {
            tempGJ.EmpId = UserContext.EmpId;
            tempGJ.Amount = 0;
            tempGJ.CrDeAmount = 0;
            tempGJ.DebitAmount = 0;
            tempGJ.CreditAmount = 0;

            var account = _accountService.CheckAccount(tempGJ.AccountId?.ToString() ?? "");

            tempGJ.AccountId = account.AccountId;

            Uow.TempGeneralJournals.Add(tempGJ);
            Uow.Commit();

            return GetListById(tempGJ);
        }

        public TempGeneralJournalList Update(TempGeneralJournal tempGJ)
        {
            var existing = GetById(tempGJ.TempGJId);

            if (existing != null)
            {
                existing.Notes = tempGJ.Notes;
                existing.Amount = tempGJ.Amount;

                if (existing.Amount != 0)
                {
                    var crDeAmount = Uow.Accounts.GetCrDeAmount(existing.AccountId.ToString() ?? "", existing.Amount);

                    existing.CrDeAmount = crDeAmount.CrDeAmount;
                    existing.DebitAmount = crDeAmount.DebitAmount;
                    existing.CreditAmount = crDeAmount.CreditAmount;
                }

                Uow.TempGeneralJournals.Update(existing);
                Uow.Commit();
            }

            return GetListById(tempGJ);
        }

        public void Delete(int tempGJId)
        {
            Uow.TempGeneralJournals.RemoveById(tempGJId);
            Uow.Commit();
        }
    }
}
