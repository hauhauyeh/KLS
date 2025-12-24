using KLS.Common;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempPurchaseItem
    {
        [Key]
        public int TempPurchaseId { get; set; }

        public int PayeeId { get; set; }

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

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FactorToBase { get; set; }

        public DateOnly? ExpiryDate { get; set; }

        public decimal? DiscountPercent { get; set; }

        public decimal? Discount { get; set; }

        public decimal? OrgPrice { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? CustomDutyRate { get; set; }

        [Column(TypeName = "decimal(9,4)")]
        public decimal? TariffPercent { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? DutySharePercent { get; private set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? ItemVolume { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? VolumeSharePercent { get; private set; }


        public decimal? BillExtTotal => Utilities.Rounding((BillQty ?? 0m) * (BillPrice ?? 0m), 2);

        public decimal? FinalExtTotal => Utilities.Rounding((FinalQty ?? 0m) * (FinalPrice ?? 0m), 2);



        public string? ItemName { get; set; }

        public string? ItemCode { get; set; }

        public decimal? CaseWeight { get; set; }

        public decimal? DutyPerCase { get; set; }

        public decimal? FreightPerCase { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? BaseFinalQty { get; set; }

        public decimal? WeightTotal { get { return Utilities.Rounding(BaseFinalQty * CaseWeight, 2); } }

        public decimal? VolumeTotal { get { return Utilities.Rounding(BaseFinalQty * ItemVolume, 2); } }

        public decimal? TotalDutyTariff => CustomDutyRate.HasValue || TariffPercent.HasValue ? (CustomDutyRate ?? 0m) + (TariffPercent ?? 0m)
        : null;
    }
}
