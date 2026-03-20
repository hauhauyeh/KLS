using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptSalesDaily2Row
    {
        [Key]
        public int Id { get; set; }

        public int? SalesNum { get; set; }

        public int? ShipId { get; set; }

        public string? PayeeName { get; set; }

        public DateOnly? ShipDate { get; set; }

        public decimal? SalesTotal { get; set; }

        public decimal? CountableTotal { get; set; }

        public decimal? CostTotal { get; set; }

        public decimal? Margin { get; set; }
    }
}
