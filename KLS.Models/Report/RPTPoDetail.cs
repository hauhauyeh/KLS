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
    public class RptPODetail
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

        [Column(TypeName = "decimal(18,6)")]
        public decimal? FactorToBase { get; set; }

        [Column(TypeName = "decimal(18,6)")]
        public decimal? BaseBillQty { get { return Utilities.Rounding(BillQty / FactorToBase, 6); } }

        public string? ItemName { get; set; }

        public string? ItemCode { get; set; }

        public decimal? CaseWeight { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? CaseVolumeInCubicMeter { get; set; }

        public string? PackSize { get; set; }

        public decimal? BillTotal
        {
            get { return Utilities.Rounding(BillQty * BillPrice, 2); }
        }

        public decimal? WeightTotal { get { return Utilities.Rounding(BaseBillQty * CaseWeight, 2); } }

        public decimal? VolumeTotal { get { return Utilities.Rounding(BaseBillQty * CaseVolumeInCubicMeter, 2); } }
    }
}
