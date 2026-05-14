using KLS.Common;
using KLS.Models.Reports;

namespace KLS.Models
{
    public class PurchaseDetailDto
    {
        public PurchaseList? Purchase { get; set; }

        public ICollection<PurchaseDetailList>? PurchaseDetails { get; set; }

        public int TotalItems
        {
            get
            {
                return PurchaseDetails.Where(c => c.LineType == EnumHelper.LineType.I.ToString())
                    .GroupBy(c => c.ItemId).Count();
            }
        }

        public decimal? TotalCases
        {
            get
            {
                return PurchaseDetails.Where(c => c.LineType == EnumHelper.LineType.I.ToString())
                    .Sum(c => c.BaseFinalQty);
            }
        }
    }
}
