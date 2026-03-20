using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models.Reports
{
    public class RptInventoryIncomingRow
    {
        [Key]
        public Int64 AutoId { get; set; }

        public int ItemId { get; set; }

        public int PurchaseNumber { get; set; }

        public string? VendorName { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? IncomingQty { get; set; }

        public string? Unit { get; set; }

        public DateOnly? ArrivalDate { get; set; }
    }
}
