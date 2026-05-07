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

        // NEW 2026-05-07: lets the autocomplete dropdown dim deleted rows
        // the same way it dims inactive rows (when the page's D toggle is on).
        public bool IsDeleted { get; set; }

        public string? ItemSearchTag { get; set; }

        public DateOnly? LastOrderDate { get; set; }

        public decimal? LastOrderQty { get; set; }

        public string? LastOrderUnit { get; set; }

        public string? PrimaryImageUrl { get; set; }

        [NotMapped]
        public decimal? Last3M { get; set; }
    }
}
