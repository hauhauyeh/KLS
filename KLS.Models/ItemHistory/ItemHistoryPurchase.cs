using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemHistoryPurchase
    {
        [Key]
        public int PurchaseDetailId { get; set; }

        public int PurchaseId { get; set; }

        public int PurchaseNumber { get; set; }

        public string? VendorDocNumber { get; set; }

        public DateOnly? ArrivalDate { get; set; }

        public string? PayeeName { get; set; }

        public decimal? ShipQty { get; set; }

        public decimal? FinalQty { get; set; }

        public string? Unit { get; set; }

        public decimal? FinalPrice { get; set; }

        public decimal? LandedCostPerCase { get; set; }

        public decimal? TotalCost { get; set; }

        public string? Type { get; set; }


        [NotMapped]
        public bool IsPdfExist { get; set; }
    }
}
