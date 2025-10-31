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
    public class TempPurchaseItem : TempPurchase
    {
        public string? ItemName { get; set; }

        public string? ItemCode { get; set; }

        public decimal? CaseWeight { get; set; }

        public decimal? CaseVolume { get; set; }

        public decimal? WeightTotal { get { return UnitType == "W" ? Utilities.Rounding(FinalQty * CaseWeight, 2) : 0; } }

        public decimal? VolumeTotal { get { return UnitType == "W" ? Utilities.Rounding(FinalQty * CaseVolume, 2) : 0; } }
    }
}
