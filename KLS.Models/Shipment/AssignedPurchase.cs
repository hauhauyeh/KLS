using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class AssignedPurchase
    {
        [Key]
        public Int64 Id { get; set; }

        public int ShipmentPurchaseId { get; set; }

        public int PurchaseNumber { get; set; }

        public DateOnly? ArrivalDate { get; set; }

        public decimal? PurchaseTotal { get; set; }

        public bool IsLocked { get; set; }

        public string? PayeeName { get; set; }
    }
}
