using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
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

        public string? ItemSearchTag { get; set; }

        public DateTime? LastOrderDate { get; set; }

        public decimal? LastOrderQty { get; set; }

        public string? LastOrderUnit { get; set; }
    }
}
