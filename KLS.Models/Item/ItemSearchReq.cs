using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemSearchReq
    {
        public string? Term { get; set; }

        // Old IsActiveOnly bool was a single "show all vs active-only" switch.
        // Replaced 2026-05-07 (Phase 2) with ambient bits that mirror product
        // list scope flags. Same truth table as Item_GetAllList. See
        // future-product-list-improve.md.
        // public bool IsActiveOnly { get; set; }
        public bool ShowInactive { get; set; }

        // 2026-08-12: mirrors Product List's NonInventory scope flag for the
        // shared ItemSearchbox preview path.
        public bool ShowNonInventory { get; set; } = true;

        // ShowDeleted removed 2026-05-08 (forward-removal of D toggle). The
        // autocomplete dropdown now always hides deleted items via an
        // unconditional WHERE clause inside Item_SearchByTerm; no caller flag
        // controls it. See future-product-list-remove-d.md.
        // public bool ShowDeleted { get; set; }
    }
}
