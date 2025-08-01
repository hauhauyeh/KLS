using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class TempGeneralJournalService : BaseService, ITempGeneralJournalService
    {
        private IChartOfAccountService _chartOfAccountService;

        public TempGeneralJournalService(IUnitOfWork uow, IChartOfAccountService chartOfAccountService) : base(uow)
        {
            _chartOfAccountService = chartOfAccountService;
        }

        public IQueryable<TempGeneralJournal> GetTempGeneralJournalDetails(int gjId, int employeeId, int? tempGJId)
        {
            return Uow.TempGeneralJournals.GetTempGeneralJournalDetails(gjId, employeeId, tempGJId);
        }

        public IQueryable<TempGeneralJournal> CreateTempGeneralJournal(TempGeneralJournal tempGeneralJournal)
        {
            tempGeneralJournal.Amount = 0;
            tempGeneralJournal.CrDeAmount = 0;
            tempGeneralJournal.DebitAmount = 0;
            tempGeneralJournal.CreditAmount = 0;

            var account = _chartOfAccountService.CheckAccount(tempGeneralJournal.AccountCode);

            tempGeneralJournal.AccountCode = account.AccountCode;

            Uow.TempGeneralJournals.Add(tempGeneralJournal);
            Uow.Commit();

            return GetTempGeneralJournalDetails(tempGeneralJournal.GJId, tempGeneralJournal.EmployeeId, tempGeneralJournal.TempGJId);
        }

        public TempGeneralJournal UpdateTempGeneralJournal(TempGeneralJournal tempGeneralJournal)
        {
            return GetTempGeneralJournalDetails(tempGeneralJournal.TempGJId, tempGeneralJournal.EmployeeId, tempGeneralJournal.TempGJId).ToList().FirstOrDefault();
        }

        public void DeleteTempGeneralJournal(int id)
        {
            Uow.TempGeneralJournals.RemoveById(id);
            Uow.Commit();
        }
    }
}
