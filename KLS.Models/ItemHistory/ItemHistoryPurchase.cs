using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class ItemHistoryPurchase
    {
        [Key]
        public int Id { get; set; }

        public int PurchaseId { get; set; }

        public int VendorDocNumber { get; set; }

        public DateOnly? ArrivalDate { get; set; }

        public string? PayeeName { get; set; }

        public decimal? ShipQty { get; set; }

        public decimal? FinalQty { get; set; }

        public string? Unit { get; set; }

        public decimal? FinalPrice { get; set; }

        public decimal? FreightPerCase { get; set; }

        public decimal? DutyPerCase { get; set; }

        public decimal? TotalCost { get; set; }

        public decimal? FreightTotal { get; set; }

        public string? Type { get; set; }
    }
}
