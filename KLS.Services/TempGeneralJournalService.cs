using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Omu.ValueInjecter;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempGeneralJournalService : BaseService, ITempGeneralJournalService
    {
        private Interfaces.IAccountService _accountService;

        public TempGeneralJournalService(IUnitOfWork uow, Interfaces.IAccountService AccountService) : base(uow)
        {
            _accountService = AccountService;
        }

        public IEnumerable<TempGeneralJournalList>? GetTempGJList(TempGJReq tempGJReq)
        {
            return Uow.TempGeneralJournals.GetTempGJList(tempGJReq)?.ToList();
        }

        public TempGeneralJournalList? GetTempGJ(TempGJReq tempGJReq)
        {
            return GetTempGJList(tempGJReq)?.FirstOrDefault();
        }

        public TempGeneralJournal GetById(int tempGJId)
        {
            return Uow.TempGeneralJournals.GetById(tempGJId);
        }

        public TempGeneralJournalList CreateTempGJ(TempGeneralJournal tempGJ)
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

            var tempGJReq = new TempGJReq
            {
                TempGJId = tempGJ.TempGJId,
                GJId = tempGJ.GJId
            };

            return GetTempGJ(tempGJReq);
        }

        public TempGeneralJournalList UpdateTempGJ(TempGeneralJournal tempGJ)
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

            var tempGJReq = new TempGJReq
            {
                TempGJId = tempGJ.TempGJId,
                GJId = tempGJ.GJId
            };

            return GetTempGJ(tempGJReq);
        }

        public void DeleteTempGJ(int tempGJId)
        {
            Uow.TempGeneralJournals.RemoveById(tempGJId);
            Uow.Commit();
        }
    }
}
