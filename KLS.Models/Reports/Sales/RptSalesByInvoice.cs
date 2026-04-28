using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptSalesByInvoiceRow
    {
        [Key]
        public int Id { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public int? SalesNumber { get; set; }

        public int? ParentSalesNumber { get; set; }

        public string? DocType { get; set; }

        public int? ShipId { get; set; }

        public string? PayeeName { get; set; }

        public int? SalesRepId { get; set; }

        public decimal? InvoiceTotal { get; set; }

        public decimal? CountableTotal { get; set; }

        public decimal? CostTotal { get; set; }

        public decimal? MarginAmount { get; set; }

        public decimal? MarginPercent { get; set; }
    }
}
