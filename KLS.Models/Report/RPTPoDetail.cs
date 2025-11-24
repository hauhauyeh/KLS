using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class RPTPoDetail
    {
        [Key]
        public int PurchaseDetailId { get; set; }

        public int PurchaseId { get; set; }

        public int ItemId { get; set; }

        public string? LineType { get; set; }

        public string? Unit { get; set; }

        public decimal? OrdQty0 { get; set; }

        public decimal? ShipQty { get; set; }

        public decimal? BillQty { get; set; }

        public decimal? BillPrice { get; set; }

        public decimal? OrdQty1 { get; set; }

        public decimal? ReceiveQty { get; set; }

        public decimal? FinalQty { get; set; }

        public decimal? FinalPrice { get; set; }

        public string? Notes { get; set; }

        //public int NormalizedUnit { get; set; }

        public string? ItemName { get; set; }

        //Change filed Name and Data Type as per Item Table (Pending)
        //public int Weight { get; set; }
        //public int Volume { get; set; }
        //public int ItemDescX1 { get; set; }
        //public int PackSize { get; set; }
    }
}
