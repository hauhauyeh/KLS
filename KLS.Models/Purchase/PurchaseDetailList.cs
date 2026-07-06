using KLS.Common;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace KLS.Models
{
    public class PurchaseDetailList
    {
        [Key]
        public int PurchaseDetailId { get; set; }
        public int PurchaseId { get; set; }
        public int? ItemId { get; set; }

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
        public string? ItemName { get; set; }
        public string? ItemBoxDesc { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FactorToBase { get; set; }   // 2026-07-06: now sourced from ItemUnit by Purchase_GetDetail (was the pd snapshot)

        // 2026-07-06: MultipleToBase from ItemUnit (source of truth); default 1 = identity.
        public int MultipleToBase { get; set; } = 1;

        public decimal? BillTotal => Utilities.Rounding((BillQty ?? 0m) * (BillPrice ?? 0m), 2);
        public decimal? FinalTotal => Utilities.Rounding((FinalQty ?? 0m) * (FinalPrice ?? 0m), 2);

        // 2026-07-06: base qty = qty * MultipleToBase / FactorToBase (both from ItemUnit via Purchase_GetDetail).
        // Keeps the FinalQty ?? OrdQty1 fallback (un-received lines show ordered base qty in Quick View's Total Cases).
        [Column(TypeName = "decimal(18,6)")]
        public decimal? BaseFinalQty { get { return Utilities.Rounding((FinalQty ?? OrdQty1) * MultipleToBase / FactorToBase, 6); } }
    }
}
