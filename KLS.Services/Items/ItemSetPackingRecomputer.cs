using System.Linq;
using KLS.Contract.Interfaces;
using KLS.Contract.Items;

namespace KLS.Services.Items
{
    /// <summary>
    /// Shared helper that reloads an item's units fresh from the DB, formats the
    /// canonical SetPacking string, and persists. Used by both ItemUnitService
    /// (per-mutation) and ItemService.Save (post-save tail call).
    ///
    /// Reloads via Uow.ItemUnits.Find rather than relying on EF nav collections,
    /// because callers may add/delete units via DbSet operations that don't
    /// propagate to a previously-loaded Item.ItemUnits navigation property.
    /// </summary>
    public static class ItemSetPackingRecomputer
    {
        // Returns the canonical SetPacking that was persisted (empty string if
        // the item wasn't found). Callers can return it as part of their
        // response payload so the UI can patch its local copy without a
        // separate GET.
        public static string Apply(IUnitOfWork uow, int itemId)
        {
            var item = uow.Items.GetById(itemId);
            if (item == null) return string.Empty;

            var units = uow.ItemUnits
                .Find(u => u.ItemId == itemId)
                .ToList();

            var canonical = SetPackingFormatter.Format(units);
            item.SetPacking = canonical;
            uow.Items.Update(item);
            uow.Commit();
            return canonical;
        }
    }
}
