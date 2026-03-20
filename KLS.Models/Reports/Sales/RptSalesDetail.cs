using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptSalesDetailRow
    {
        [Key]
        public int RowId { get; set; }

        public int? SalesNum { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemDesc1 { get; set; }

        public decimal? ShipQty { get; set; }

        public decimal? BillQty { get; set; }

        public decimal? Price { get; set; }

        public decimal? ExtTotal { get; set; }

        public decimal? Cost { get; set; }

        public decimal? Margin { get; set; }

        public string? SalesRepName { get; set; }
    }
}
