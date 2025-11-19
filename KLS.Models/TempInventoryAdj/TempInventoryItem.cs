using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempInventoryItem
    {
        [Key]
        public int TempAdjId { get; set; }

        public int AdjId { get; set; }

        public int ItemId { get; set; }

        public decimal? NewQty { get; set; }

        public decimal? NewPrice { get; set; }

        public string? Notes { get; set; }



        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? PackSize { get; set; }
    }
}
