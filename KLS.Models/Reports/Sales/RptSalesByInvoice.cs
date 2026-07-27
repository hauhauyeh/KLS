using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    // 2026-06-26: Rebuilt on actual journal cost. Columns now mirror Report_SalesByInvoice's
    // @COGS-based output (was: CountableTotal/CostTotal/MarginAmount derived from the stored
    // Sales margin). Amount = recognized revenue (@ISALE + @ICREDIT for credit memos),
    // Cost = recognized @COGS. IsUncosted flags invoices shipped-but-unposted or revenue-no-cost.
    public class RptSalesByInvoiceRow
    {
        [Key]
        public int SalesId { get; set; }

        public int? SalesNumber { get; set; }

        public string? SalesDocNumber { get; set; }

        public DateOnly? ShipDate { get; set; }

        public string? ShipRoute { get; set; }

        public string? DocType { get; set; }

        public int? ParentSalesNumber { get; set; }

        public int? ShipId { get; set; }

        public string? Customer { get; set; }

        public int? SalesRepId { get; set; }

        public decimal? InvoiceTotal { get; set; }

        public decimal? Amount { get; set; }

        public decimal? Cost { get; set; }

        public decimal? GrossMargin { get; set; }

        public decimal? GrossMarginPerc { get; set; }

        public bool IsUncosted { get; set; }
    }
}
