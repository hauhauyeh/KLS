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
    public class EmailLogService : BaseService, IEmailLogService
    {
        public EmailLogService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<EmailLogDTO> GetPagedList(EmailLogReq emailLogReq)
        {
            var loglist = Uow.EmailLogs.GetPagedList(emailLogReq);

            var totalRecords = Uow.EmailLogs.Count(emailLogReq);

            return new PagingResponse<EmailLogDTO>(totalRecords, emailLogReq.Pageno, emailLogReq.Pagesize)
            {
                RowData = loglist,
            };
        }
    }
}
