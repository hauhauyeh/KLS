using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class InventoryAdjList
    {
        [Key]
        public int AutoId { get; set; }

        public int AdjId { get; set; }

        public int AdjDetailId { get; set; }

        public int AdjNumber { get; set; }

        public DateOnly? AdjDate { get; set; }

        public string? AdjType { get; set; }

        public int ItemId { get; set; }

        public decimal? NewQty { get; set; }

        public decimal? NewPrice { get; set; }

        public string? DetailNotes { get; set; }

        public string? Notes { get; set; }

        public DateOnly? PrevAdjDate { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public decimal? QtyBefore { get; set; }

        public decimal? PriceBefore { get; set; }
    }
}
