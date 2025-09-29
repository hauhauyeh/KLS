using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services.Interfaces
{
    public interface IGeneralJournalService
    {
        PagingResponse<GeneralJournal> GetAllGeneralJournals(GJReq gjReq);

        GeneralJournal GetById(int gjId);

        GeneralJournal SaveGeneralJournal(GeneralJournal generalJournal);

        void DeleteGeneralJournal(int gjId);

        void UpdateNotes(GeneralJournal gj);

        void InjectGeneralJournal(int gjId, bool isClone);
    }
}
