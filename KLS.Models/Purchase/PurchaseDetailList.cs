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
        public decimal? FactorToBase { get; set; }

        public decimal? BillTotal => Utilities.Rounding((BillQty ?? 0m) * (BillPrice ?? 0m), 2);
        public decimal? FinalTotal => Utilities.Rounding((FinalQty ?? 0m) * (FinalPrice ?? 0m), 2);

        [Column(TypeName = "decimal(18,6)")]
        public decimal? BaseFinalQty { get { return Utilities.Rounding((FinalQty ?? OrdQty1) / FactorToBase, 6); } }
    }
}
