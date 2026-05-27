using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class PurchaseItemCostList
    {
        [Key]
        public int ItemId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public decimal? RecentCost { get; set; }

        public decimal? RecentCostB4 { get; set; }

        public decimal? CostChangePercent { get; set; }
    }
}
