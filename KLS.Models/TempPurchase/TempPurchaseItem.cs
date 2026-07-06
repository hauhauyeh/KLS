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

        public decimal? ImportCommission { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FactorToBase { get; set; }

        // 2026-07-06: MultipleToBase from ItemUnit (live via ItemUnitId, TempPurchase_GetList); default 1 = identity.
        // Numerator for combine-up: base qty = qty * MultipleToBase / FactorToBase. FactorToBase stays the temp snapshot.
        public int MultipleToBase { get; set; } = 1;

        public DateOnly? ExpiryDate { get; set; }

        public decimal? DiscountPercent { get; set; }

        public decimal? Discount { get; set; }

        public decimal? OrgPrice { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? CustomDutyRate { get; set; }

        [Column(TypeName = "decimal(9,4)")]
        public decimal? TariffPercent { get; set; }

        //[Column(TypeName = "decimal(18,6)")]
        //public decimal? DutySharePercent { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? ItemVolume { get; set; }

        //[Column(TypeName = "decimal(18,6)")]
        //public decimal? VolumeSharePercent { get; set; }


        public decimal? BillExtTotal => Utilities.Rounding((BillQty ?? 0m) * (BillPrice ?? 0m), 2);

        public decimal? FinalExtTotal => Utilities.Rounding((FinalQty ?? 0m) * (FinalPrice ?? 0m), 2);



        public string? ItemName { get; set; }

        public string? ItemCode { get; set; }

        public decimal? CaseWeight { get; set; }

        // 2026-06-29 (Plan 2b): aggregate landed cost per case from View_PurchaseHistory (post-allocation),
        // surfaced for the inline cart display. Already returned by TempPurchase_GetList.
        public decimal? LandedCostPerCase { get; set; }

        // 2026-06-29 (Plan 2c): per-charge-type landed cost per case (from ShipmentAllocation by
        // ChargeType), for the inline "Freight $/cs · Duty $/cs" split. NULL when that charge type
        // isn't allocated on the line.
        public decimal? FreightPerCase { get; set; }
        public decimal? DutyPerCase { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? BaseFinalQty { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? BaseBillQty { get { return Utilities.Rounding(BillQty * MultipleToBase / FactorToBase, 6); } }


        public decimal? BillVolumeTotal { get { return Utilities.Rounding(BaseBillQty * ItemVolume, 2); } }

        public decimal? FinalVolumeTotal { get { return Utilities.Rounding(BaseFinalQty * ItemVolume, 2); } }

        public decimal? BillWeightTotal { get { return Utilities.Rounding(BaseBillQty * CaseWeight, 2); } }

        public decimal? FinalWeightTotal { get { return Utilities.Rounding(BaseFinalQty * CaseWeight, 2); } }

        public decimal? BillCases
        {
            get
            {
                return LineType == EnumHelper.LineType.I.ToString() ? Utilities.Rounding(BillQty * MultipleToBase / FactorToBase, 6) : 0;
            }
        }

        public decimal? FinalCases
        {
            get
            {
                return LineType == EnumHelper.LineType.I.ToString() ? Utilities.Rounding(FinalQty * MultipleToBase / FactorToBase, 6) : 0;
            }
        }

        public decimal? FreightInsideTotal
        {
            get
            {
                return (LineType == EnumHelper.LineType.A.ToString() && ItemCode == "@INVC") ? FinalExtTotal : 0;
            }
        }

        public decimal? CustomDutyInsideTotal
        {
            get
            {
                return (LineType == EnumHelper.LineType.A.ToString() && ItemCode == "@INVC") ? FinalExtTotal : 0;
            }
        }

        public decimal? TotalDutyTariff => CustomDutyRate.HasValue || TariffPercent.HasValue ? (CustomDutyRate ?? 0m) + (TariffPercent ?? 0m)
        : null;

        [NotMapped]
        public bool IsUnitChange { get; set; }
    }
}
