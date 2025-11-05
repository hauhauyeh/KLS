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

        public string LineType { get; set; }

        public int? ItemId { get; set; }

        public int? AccountId { get; set; }

        public string? UnitType { get; set; }

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

        public decimal? BillExtTotal
        {
            get { return Utilities.Rounding(BillQty * BillPrice, 2); }
            set { value = Utilities.Rounding(BillQty * BillPrice, 2); }
        }

        public decimal? FinalPrice { get; set; }

        public decimal? FinalExtTotal
        {
            get { return Utilities.Rounding(FinalQty * FinalPrice, 2); }
            set { value = Utilities.Rounding(FinalQty * FinalPrice, 2); }
        }

        public DateOnly? ExpiryDate { get; set; }

        public decimal? RetailFactor { get; set; }

        public decimal? DiscountPercent { get; set; }

        public decimal? Discount { get; set; }

        public decimal? OrgPrice { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? CustomDutyRate { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? DutySharePercent { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? ItemVolume { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? VolumeSharePercent { get; set; }



        public string? ItemName { get; set; }

        public string? ItemCode { get; set; }

        public decimal? CaseWeight { get; set; }

        public decimal? CaseVolume { get; set; }

        public decimal? WeightTotal { get { return UnitType == "W" ? Utilities.Rounding(FinalQty * CaseWeight, 2) : 0; } }

        public decimal? VolumeTotal { get { return UnitType == "W" ? Utilities.Rounding(FinalQty * CaseVolume, 2) : 0; } }
    }
}
