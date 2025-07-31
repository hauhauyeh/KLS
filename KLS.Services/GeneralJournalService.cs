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
    public class GeneralJournalService : BaseService, IGeneralJournalService
    {
        public GeneralJournalService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<GeneralJournal> GetAllGeneralJournal(GeneralJournalReq generalJournalReq)
        {
            var list = Uow.GeneralJournals.GetAllGeneralJournal(generalJournalReq);

            var totalRecords = Uow.GeneralJournals.GetAllGeneralJournal(generalJournalReq).ToList().Count();

            return new PagingResponse<GeneralJournal>(totalRecords, generalJournalReq.Pageno, generalJournalReq.Pagesize)
            {
                RowData = list,
            };
        }
    }
}
