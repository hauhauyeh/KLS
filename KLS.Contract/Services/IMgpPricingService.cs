using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IMgpPricingService
    {
        List<MgpPriceSheetTargetDto> GetPriceSheetTargets();
    }
}
