using System;

namespace KLS.Models
{
    public class PurchaseDetailValidationRow
    {
        public int PurchaseDetailId { get; set; }
        public int PurchaseId { get; set; }
        public int? LineId { get; set; }
        public string? LineType { get; set; }
        public int? ItemId { get; set; }
        public int? AccountId { get; set; }
        public int? ItemUnitId { get; set; }
        public string? Unit { get; set; }
        public string? Notes { get; set; }
        public bool IsFree { get; set; }
        public bool IsOut { get; set; }
        public bool IsCRCG { get; set; }
        public decimal? OrdQty0 { get; set; }
        public decimal? ShipQty { get; set; }
        public decimal? BillQty { get; set; }
        public decimal? OrdQty1 { get; set; }
        public decimal? ReceiveQty { get; set; }
        public decimal? FinalQty { get; set; }
        public decimal? BillPrice { get; set; }
        public decimal? FinalPrice { get; set; }
        public decimal? ImportCommission { get; set; }
        public decimal? FactorToBase { get; set; }
        public DateOnly? ExpiryDate { get; set; }
        public decimal? CustomDutyRate { get; set; }
        public decimal? TariffPercent { get; set; }
        public decimal? ItemVolume { get; set; }
    }
}
