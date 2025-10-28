using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class TempPurchase
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int TempPurchaseId { get; set; }

        public int EmpId { get; set; }

        public int PurchaseId { get; set; }

        public int? LineId { get; set; }

        public string LineType { get; set; }

        public int? ItemId { get; set; }

        public int? AccountId { get; set; }

        public string? UnitType { get; set; }

        public string? Unit { get; set; }

        public string? Notes { get; set; }

        public decimal? OrdQty0 { get; set; }

        public decimal? ShipQty { get; set; }

        public decimal? BillQty { get; set; }

        public decimal? OrdQty1 { get; set; }

        public decimal? ReceiveQty { get; set; }

        public decimal? FinalQty { get; set; }

        public decimal? BillPrice { get; set; }

        public decimal? BillExtTotal { get; set; }

        public decimal? FinalPrice { get; set; }

        public decimal? FinalExtTotal { get; set; }

        public DateOnly? ExpiryDate { get; set; }

        public decimal? RetailFactor { get; set; }

        public decimal? DiscountPercent { get; set; }

        public decimal? Discount { get; set; }

        public decimal? OrgPrice { get; set; }

        public decimal? CustomDutyRate { get; set; }

        public decimal? DutySharePercent { get; set; }

        public decimal? ItemVolume { get; set; }

        public decimal? VolumeSharePercent { get; set; }

        public string? ChangeStatus { get; set; }

        public int? PurchaseDetailId { get; set; }
    }
}
