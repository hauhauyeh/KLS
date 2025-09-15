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
        IQueryable<GeneralJournal> GetAllGeneralJournals(GJReq gJReq);

        int SaveGeneralJournal(GeneralJournal generalJournal);

        void InjectGeneralJournal(int gjId);
    }
}
