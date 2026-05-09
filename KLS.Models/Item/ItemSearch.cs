using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemSearch
    {
        [Key]
        public int ItemId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? BaseUnit { get; set; }

        public decimal? LCloseQty { get; set; }

        public bool Inactive { get; set; }

        // IsDeleted projection removed 2026-05-08 (forward-removal of D toggle).
        // Neither Item_SearchByTerm nor Item_ListActiveForKeybox projects
        // i.IsDeleted now, so the DTO must not require this column or EF
        // will throw on materialization (this was the root cause of the
        // 2026-05-08 keybox-cache failure). The autocomplete dropdown's
        // dim binding now uses item.Inactive only.
        // public bool IsDeleted { get; set; }

        public string? ItemSearchTag { get; set; }

        public DateOnly? LastOrderDate { get; set; }

        public decimal? LastOrderQty { get; set; }

        public string? LastOrderUnit { get; set; }

        public string? PrimaryImageUrl { get; set; }

        [NotMapped]
        public decimal? Last3M { get; set; }
    }
}
