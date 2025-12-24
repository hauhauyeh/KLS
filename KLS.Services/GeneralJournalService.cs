using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
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
        private readonly IDeleteLogService _deleteLogService;

        public GeneralJournalService(IUnitOfWork uow, IDeleteLogService deleteLogService) : base(uow)
        {
            _deleteLogService = deleteLogService;
        }

        public PagingResponse<GeneralJournal> GetPagedList(GJReq gJReq)
        {
            var list = Uow.GeneralJournals.GetPagedList(gJReq);

            var totalRecords = Uow.GeneralJournals.Count(gJReq);

            return new PagingResponse<GeneralJournal>(totalRecords, gJReq.Pageno, gJReq.Pagesize)
            {
                RowData = list,
            };
        }

        public GeneralJournal GetById(int gjId)
        {
            return Uow.GeneralJournals.GetById(gjId);
        }

        public GeneralJournal Save(GeneralJournal generalJournal)
        {
            var newGJId = Uow.GeneralJournals.Save(generalJournal);

            return GetById(newGJId);
        }

        public void Delete(int gjId)
        {
            var gj = GetById(gjId);

            if (gj != null && !gj.IsLocked)
            {
                Uow.GeneralJournals.Find(c => c.GJId == gjId).ExecuteDelete();

                string docType = EnumHelper.DocType.GeneralJournal.ToString();

                _deleteLogService.Add(docType, gjId);
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

        public void Inject(int gjId, bool isClone)
        {
            Uow.GeneralJournals.Inject(gjId, isClone);
        }
    }
}
