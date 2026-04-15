using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class CustBoughtItemPanelRow
    {
        [Key]
        public int ItemId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? SetPacking { get; set; }

        public string? CategoryName { get; set; }

        public int? CategorySort { get; set; }

        public DateOnly? LastOrderDate { get; set; }

        public decimal? LastOrderQty { get; set; }

        public decimal? TotalQty1Y { get; set; }

        public decimal? TotalQty3M { get; set; }

        public int? OrderCount1Y { get; set; }
    }
}
