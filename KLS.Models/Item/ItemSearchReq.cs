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
        // Replaced 2026-05-07 (Phase 2) with two independent ambient bits that
        // mirror the I and D toggles on the product list page. Same truth table
        // as Item_GetAllList. See future-product-list-improve.md.
        // public bool IsActiveOnly { get; set; }
        public bool ShowInactive { get; set; }

        public bool ShowDeleted { get; set; }
    }
}
