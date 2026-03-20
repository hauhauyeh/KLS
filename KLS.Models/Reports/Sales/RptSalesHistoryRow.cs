using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptSalesHistoryRow
    {
        [Key]
        public int SalesId { get; set; }

        public int SalesNumber { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public decimal? SalesTotal { get; set; }
    }
}
