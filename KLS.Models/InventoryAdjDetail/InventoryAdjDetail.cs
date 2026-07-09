using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class InventoryAdjDetail
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int AdjDetailId { get; set; }

        public int AdjId { get; set; }

        public int ItemId { get; set; }

        public decimal? NewQty { get; set; }

        public decimal? QtyDiffer { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? NewPrice { get; set; }

        public decimal? SoldQty { get; set; }

        public string? Notes { get; set; }
    }
}
