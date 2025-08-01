using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface ITempGeneralJournalService
    {
        IQueryable<TempGeneralJournal> GetTempGeneralJournalDetails(int gjId, int employeeId, int? tempGJId);

        IQueryable<TempGeneralJournal> CreateTempGeneralJournal(TempGeneralJournal tempGeneralJournal);

        TempGeneralJournal UpdateTempGeneralJournal(TempGeneralJournal tempGeneralJournal);

        void DeleteTempGeneralJournal(int id);
    }
}
