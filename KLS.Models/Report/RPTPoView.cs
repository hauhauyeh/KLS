using KLS.Common;
using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace KLS.Models
{
    public class RptPOView
    {
        public Company? Company { get; set; }

        public RptPO? RptPO { get; set; }

        public List<RptPODetail>? RptPODetail { get; set; }

        public int TotalItem
        {
            get
            {
                return RptPODetail.Where(c => c.LineType == EnumHelper.LineType.I.ToString()).GroupBy(c => c.ItemId).Count();
            }
        }

        public decimal? TotalCase
        {
            get
            {
                return RptPODetail.Where(c => c.LineType == EnumHelper.LineType.I.ToString()).Sum(c => c.BaseFinalQty);
            }
        }


        public decimal? TotalWeight { get { return RptPODetail?.Sum(c => c.WeightTotal); } }

        public decimal? TotalVolume { get { return RptPODetail?.Sum(c => c.VolumeTotal); } }
    }
}
