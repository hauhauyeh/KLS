using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Interfaces
{
    public interface IGeneralJournalRepository : IRepository<GeneralJournal>
    {
        IQueryable<GeneralJournal> GetPagedList(GJReq gJReq);

        int Count(GJReq gJReq);

        int Save(GeneralJournal generalJournal);

        void Inject(int gjId, bool isClone);
    }
}
