using KLS.Contract.Interfaces;
using KLS.Models;
using KLS.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
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

        public PagingResponse<GeneralJournal> GetAllGeneralJournals(GJReq gJReq)
        {
            var list = Uow.GeneralJournals.GetAllGeneralJournals(gJReq);

            var totalRecords = Uow.GeneralJournals.CountAllGeneralJournals(gJReq);

            return new PagingResponse<GeneralJournal>(totalRecords, gJReq.Pageno, gJReq.Pagesize)
            {
                RowData = list,
            };
        }

        public GeneralJournal GetById(int gjId)
        {
            return Uow.GeneralJournals.GetById(gjId);
        }

        public GeneralJournal SaveGeneralJournal(GeneralJournal generalJournal)
        {
            var newGJId = Uow.GeneralJournals.SaveGeneralJournal(generalJournal);

            return GetById(newGJId);
        }

        public void DeleteGeneralJournal(int gjId)
        {
            var gj = GetById(gjId);

            if (gj != null && !gj.IsLocked)
            {
                Uow.GeneralJournals.Find(c => c.GJId == gjId).ExecuteDelete();
                //Uow.GeneralJournals.RemoveById(gjId);
                //Uow.Commit();
            }
        }

        public void UpdateNotes(GeneralJournal gj)
        {
            var existing = GetById(gj.GJId);

            if (existing != null)
            {
                existing.Notes = gj.Notes;
                existing.UpdatedAt = DateTime.UtcNow;

                Uow.GeneralJournals.Update(existing);
                Uow.Commit();

                //Uow.GeneralJournals.Find(c => c.GJId == existing.GJId)
                //    .ExecuteUpdate(setters => setters.SetProperty(x => x.Notes, x => gj.Notes)
                //    .SetProperty(x => x.UpdatedAt, x => DateTime.UtcNow));
            }
        }

        public void InjectGeneralJournal(int gjId, bool isClone)
        {
            Uow.GeneralJournals.InjectGeneralJournal(gjId, isClone);
        }
    }
}
