using KLS.Models.Intercompany;

namespace KLS.Contract.Services
{
    public interface IIntercompanyItemSyncService
    {
        List<IntercompanyItemSyncTargetDto> Targets();

        IntercompanyItemSyncPreviewDto Preview(string targetCode);

        IntercompanyItemSyncRunDto Sync(string targetCode);
    }
}
