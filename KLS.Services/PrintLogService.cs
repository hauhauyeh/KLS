using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;
using Microsoft.AspNetCore.Hosting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Services
{
    public class PrintLogService : BaseService, IPrintLogService
    {
        private readonly IWebHostEnvironment _env;

        public PrintLogService(IUnitOfWork uow, IWebHostEnvironment env) : base(uow)
        {
            _env = env;
        }

        public IEnumerable<PrintLog> GetLogs()
        {
            return Uow.PrintLogs.Find(c => c.IsPrinted == false).OrderBy(c => c.PrintLogId);
        }

        public PrintLog GetById(int logId)
        {
            return Uow.PrintLogs.GetById(logId);
        }

        public void Create(PrintLog printLog)
        {
            Uow.PrintLogs.Add(printLog);
            Uow.Commit();
        }

        public void CreateBatch(ICollection<PrintLog> printLogs)
        {
            Uow.PrintLogs.AddRange(printLogs);
            Uow.Commit();
        }

        public void Update(int logId)
        {
            var log = GetById(logId);

            if (log != null)
            {
                log.PrintedAt = DateTime.UtcNow;
                log.IsPrinted = true;
                Uow.PrintLogs.Update(log);
                Uow.Commit();
            }
        }


        //--background service call
        public string GetDocPDF(int logId)
        {
            var log = GetById(logId);

            var pathFromDb = log.DocPath;
            if (string.IsNullOrWhiteSpace(pathFromDb))
                throw new FileNotFoundException("File path not found.");

            string physicalPath;

            // If DB contains absolute path, use it as-is
            if (Path.IsPathRooted(pathFromDb))
            {
                physicalPath = pathFromDb;
            }
            else
            {
                // If DB contains relative path: build from wwwroot
                var rel = pathFromDb.Replace('/', Path.DirectorySeparatorChar)
                                    .Replace('\\', Path.DirectorySeparatorChar)
                                    .TrimStart(Path.DirectorySeparatorChar);

                physicalPath = Path.Combine(_env.WebRootPath, rel); // wwwroot + Pdf/Invoice-28.pdf
            }

            if (!File.Exists(physicalPath))
                throw new FileNotFoundException("PDF file not found.");

            return physicalPath;
            //return System.IO.File.ReadAllBytes(physicalPath);
        }
    }
}
