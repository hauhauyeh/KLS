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
    public class EmailLogService : BaseService, IEmailLogService
    {
        public EmailLogService(IUnitOfWork uow) : base(uow)
        {

        }

        public PagingResponse<EmailLogDTO> GetEmailLogs(EmailLogReq emailLogReq)
        {
            var loglist = Uow.EmailLogs.GetEmailLogs(emailLogReq);

            var totalRecords = Uow.EmailLogs.GetEmailLogs(emailLogReq).ToList().Count();

            return new PagingResponse<EmailLogDTO>(totalRecords, emailLogReq.Pageno, emailLogReq.Pagesize)
            {
                RowData = loglist,
            };
        }
    }
}
