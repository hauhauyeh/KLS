using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemUpdateReq
    {
        public int ItemId { get; set; }

        public decimal? DefaultCost { get; set; }

        public decimal? P1 { get; set; }

        public decimal? RetailPrice { get; set; }

        [Column(TypeName = "decimal(18, 4)")]
        public decimal? RetailProfitPercent { get; set; }
    }
}
