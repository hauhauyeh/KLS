using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class BombSalesReq
    {
        public string? DateRange { get; set; }

        public DateOnly? ShipDate { get; set; }

        public int? ItemId { get; set; }

        public decimal? ShipQty { get; set; }

        public string? Unit { get; set; }

        public decimal? Price { get; set; }

        public string? ShipRoute { get; set; }

        public int? PayeeId { get; set; }

        public int? SalesNumber { get; set; }

        public bool IsPound { get; set; }
    }
}
