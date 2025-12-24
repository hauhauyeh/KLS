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

        public int ItemId { get; set; }

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
        public decimal? BaseFinalQty { get; set; }

        public string? ItemName { get; set; }

        public decimal? CaseWeight { get; set; }

        [Column(TypeName = "decimal(18,4)")]
        public decimal? CaseVolumeInCubicMeter { get; set; }

        public string? SetPacking { get; set; }

        public string? ItemCode { get; set; }

        public decimal? FinalTotal
        {
            get { return Utilities.Rounding(FinalQty * FinalPrice, 2); }
        }

        public decimal? WeightTotal { get { return Utilities.Rounding(BaseFinalQty * CaseWeight, 2); } }

        public decimal? VolumeTotal { get { return Utilities.Rounding(BaseFinalQty * CaseVolumeInCubicMeter, 2); } }

        //Change filed Name and Data Type as per Item Table (Pending)
        //public int Weight { get; set; }
        //public int Volume { get; set; }
        //public int ItemDescX1 { get; set; }
        //public int PackSize { get; set; }
    }
}
