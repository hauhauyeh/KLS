using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class InventoryClosingDetail
    {
        [Key]
        public int ItemId { get; set; }

        public decimal? ClosingQty { get; set; }

        public decimal? AverageCost { get; set; }

    }
}
