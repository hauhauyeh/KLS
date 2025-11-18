using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempInventoryAdj
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempAdjId { get; set; }

        public int EmpId { get; set; }

        public int AdjId { get; set; }

        public int ItemId { get; set; }

        public decimal? NewQty { get; set; }

        public decimal? QtyDiffer { get; set; }

        public decimal? NewPrice { get; set; }

        public string? Notes { get; set; }

        public string? ChangeStatus { get; set; }

        public int? AdjDetailId { get; set; }
    }
}
