using KLS.Contract.Interfaces;
using KLS.Contract.Services;
using KLS.Models;

namespace KLS.Services
{
    public class LabelPrintLogService : BaseService, ILabelPrintLogService
    {
        public LabelPrintLogService(IUnitOfWork uow) : base(uow)
        {
        }

        public List<LabelPrintLog> GetLogs()
        {
            return Uow.LabelPrintLogs.Find(c => !c.IsPrinted)
                .OrderBy(c => c.PrintReqTime)
                .ToList();
        }

        public LabelPrintLog? Create(PrintLabelReq labelReq)
        {
            var warehouse = Uow.WarehousePCs.Find(c => c.IPAddress == labelReq.IPAddress).FirstOrDefault();

            if (warehouse != null)
            {
                var printLog = new LabelPrintLog
                {
                    PrintContent = labelReq.Content,
                    PrintCopy = labelReq.PrintCopy,
                    IsCenter = labelReq.IsCenter,
                    IPAddress = labelReq.IPAddress,
                    PrinterName = warehouse.PrinterName
                };

                Uow.LabelPrintLogs.Add(printLog);
                Uow.Commit();
                return printLog;
            }
            return null;
        }

        public LabelPrintLog? Update(int logId)
        {
            var existing = Uow.LabelPrintLogs.GetById(logId);
            if (existing == null)
                return null;

            existing.IsPrinted = true;
            existing.PrintedAt = DateTime.UtcNow;

            Uow.LabelPrintLogs.Update(existing);
            Uow.Commit();
            return existing;
        }
    }
}
