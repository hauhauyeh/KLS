using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemListReq : PagingRequest
    {
        public int? VendorId { get; set; }

        public string? Container { get; set; }

        public int? CategoryId { get; set; }

        // Old "Visibility" string was a 4-way enum (active / inactive / deleted /
        // null). Replaced 2026-05-07 with two independent ambient bits that map
        // straight to the I and D checkboxes on the product list page. See
        // future-product-list-improve.md, Phase 1.2.
        // public string? Visibility { get; set; }
        public bool ShowInactive { get; set; }

        // ShowDeleted removed 2026-05-08 (forward-removal of D toggle). Deleted
        // items are now always hidden on the page list via an unconditional
        // WHERE clause inside Item_GetAllList; no caller flag controls it.
        // See future-product-list-remove-d.md.
        // public bool ShowDeleted { get; set; }
    }
}
