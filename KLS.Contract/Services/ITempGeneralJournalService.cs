using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface ITempGeneralJournalService
    {
        IEnumerable<TempGeneralJournalList>? GetTempGJList(TempGJReq tempGJReq);

        TempGeneralJournal GetById(int tempGJId);

        TempGeneralJournalList CreateTempGJ(TempGeneralJournal tempGJ);

        TempGeneralJournalList UpdateTempGJ(TempGeneralJournal tempGJ);

        void DeleteTempGJ(int tempGJId);
    }
}
