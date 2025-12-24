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
        IEnumerable<TempGeneralJournalList>? GetList(TempGJReq tempGJReq);

        TempGeneralJournal GetById(int tempGJId);

        TempGeneralJournalList Create(TempGeneralJournal tempGJ);

        TempGeneralJournalList Update(TempGeneralJournal tempGJ);

        void Delete(int tempGJId);
    }
}
