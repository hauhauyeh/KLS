using KLS.Common;
using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class DeleteLogService : BaseService, IDeleteLogService
    {
        public DeleteLogService(IUnitOfWork uow) : base(uow)
        {

        }

        public void Add(string docType, int docId)
        {
            var deleteLog = new DeleteLog()
            {
                LogDate = DateTime.UtcNow,
                SourceDocType = docType,
                SourceDocId = docId,
                DeletedBy = UserContext.EmpId
            };

            Uow.DeleteLogs.Add(deleteLog);
            Uow.Commit();
        }
    }
}
