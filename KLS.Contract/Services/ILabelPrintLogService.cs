using KLS.Models;

namespace KLS.Contract.Services
{
    public interface ILabelPrintLogService
    {
        List<LabelPrintLog> GetLogs();

        LabelPrintLog? Create(PrintLabelReq labelReq);

        LabelPrintLog? Update(int logId);
    }
}
