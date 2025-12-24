using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IGeneralJournalService
    {
        PagingResponse<GeneralJournal> GetPagedList(GJReq gjReq);

        GeneralJournal GetById(int gjId);

        GeneralJournal Save(GeneralJournal generalJournal);

        void Delete(int gjId);

        void UpdateNotes(GeneralJournal gj);

        void Inject(int gjId, bool isClone);
    }
}
