using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
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

        // Phase C: split-helper reopen hydration (per-bill freight inputs). NULL until a freight split is saved.
        [Column(TypeName = "decimal(9,2)")]
        public decimal? PalletCount { get; set; }

        [Column(TypeName = "decimal(5,2)")]
        public decimal? SpacePercent { get; set; }

        // 2026-07-13 (Slice B): reference-only shipment link; no landed cost.
        public bool IsDropShip { get; set; }
    }
}
