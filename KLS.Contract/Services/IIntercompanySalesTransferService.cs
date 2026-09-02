using KLS.Models.Intercompany;

namespace KLS.Contract.Services
{
    public interface IIntercompanySalesTransferService
    {
        List<IntercompanySalesTransferTargetDto> Targets();

        IntercompanySalesTransferPreviewDto Preview(string targetCode, DateOnly fromShipDate, DateOnly toShipDate);

        IntercompanySalesTransferCreateResultDto Create(IntercompanySalesTransferCreateReq req, int empId);
    }
}
