using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    // Result of [Shipment_BillBasisUsability] @ShipmentId (Phase C). One row per assigned bill.
    // Flags are 0/1 ints (the SP returns INT, not BIT); the service treats 1 as usable.
    public class BillBasisUsability
    {
        [Key]
        public int ShipmentPurchaseId { get; set; }

        public int PurchaseId { get; set; }

        public int VolumeOk { get; set; }

        public int WeightOk { get; set; }

        public int ValueOk { get; set; }

        public int QuantityOk { get; set; }

        public int DutyTariffOk { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal DutyTariffAmount { get; set; }

        public int LineCount { get; set; }

        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalValue { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal TotalQty { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal TotalDutyTariffWeight { get; set; }

        // 2026-07-13 (Slice B): reference-only; excluded from basis CTE, returned for UI.
        public bool IsDropShip { get; set; }
    }
}
