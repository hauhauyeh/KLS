using KLS.Models;

namespace KLS.Contract.Dtos.Item
{
    /// <summary>
    /// Returned from ItemUnit mutation endpoints (Update/Create/Delete) so the
    /// caller can patch its local cache without a separate GET.
    /// SetPacking is the canonical value re-computed by the backend after the
    /// mutation (single source of truth). Unit is populated only by Create.
    /// </summary>
    public class ItemUnitMutationResult
    {
        public int ItemId { get; set; }
        public string SetPacking { get; set; } = string.Empty;
        public ItemUnit? Unit { get; set; }
    }
}
