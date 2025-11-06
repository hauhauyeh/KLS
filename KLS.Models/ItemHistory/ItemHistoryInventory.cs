using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemHistoryInventory
    {
        [Key]
        public Int64 TxDetailId { get; set; }

        public Int64 TxId { get; set; }

        public DateOnly? TxDate { get; set; }

        public string? SourceDocType { get; set; }

        public int? SourceDocNumber { get; set; }

        public decimal? InventoryQty { get; set; }

        public decimal? Price { get; set; }

        public decimal? ClosingQty { get; set; }

        public decimal? AverageCost { get; set; }
    }
}
