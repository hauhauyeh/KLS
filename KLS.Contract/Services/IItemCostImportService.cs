using KLS.Models;

namespace KLS.Contract.Services
{
    public interface IItemCostImportService
    {
        /// <summary>Step 1. Store the upload, parse it, resolve every row by unit barcode. Writes nothing.</summary>
        ItemCostImportPreviewRes Preview(ItemCostImportPreviewReq req);

        /// <summary>Step 2. Stage pending costs from the file on disk, in one transaction.</summary>
        ItemCostImportResult Import(ItemCostImportTokenReq req);

        /// <summary>The Pending / Apply card.</summary>
        ItemCostPendingStatusRes GetPendingStatus();

        /// <summary>Apply Now. Guards (schedule day, once per week, something pending) are enforced by the SP.</summary>
        ItemCostApplyResult ApplyPending();
    }
}
