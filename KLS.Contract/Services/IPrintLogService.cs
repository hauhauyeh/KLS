using KLS.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Contract.Services
{
    public interface IPrintLogService
    {
        IEnumerable<PrintLog> GetLogs();

        PrintLog GetById(int logId);

        void Create(PrintLog printLog);

        void CreateBatch(ICollection<PrintLog> printLogs);

        void Update(int logId);


        string GetDocPDF(int logId);
    }
}
