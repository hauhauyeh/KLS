using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptSalesCommissionRow
    {
        [Key]
        public int Rn { get; set; }

        public int? SalesRepId { get; set; }

        public int? CustId { get; set; }

        public decimal? PmtAmt { get; set; }

        public decimal? NonSales { get; set; }

        public string? SalesRepName { get; set; }

        public string? CustName { get; set; }
    }

    public class RptSalesCommission2Row
    {
        [Key]
        public int Id { get; set; }

        public int? SalesRepId { get; set; }

        public string? SalesRepName { get; set; }

        public int? SalesNumber { get; set; }

        public string? SalesDocNumber { get; set; }

        public int? ShipId { get; set; }

        public string? PayeeName { get; set; }

        public DateOnly? ShipDate { get; set; }

        public decimal? SalesTotal { get; set; }

        public decimal? CountableTotal { get; set; }

        public decimal? CostTotal { get; set; }

        public decimal? Margin { get; set; }
    }

    // 2026-06-26: Sales Commission 3 -- same shape as v2, fed by Report_SalesCommission3 which
    // sources cost from real @COGS (not FIFOCost) and revenue from @ISALE+@ICREDIT−DiscountApplied.
    // SalesNum here is the real invoice number (v2's column actually carried SalesId).
    public class RptSalesCommission3Row
    {
        [Key]
        public int Id { get; set; }

        public int? SalesRepId { get; set; }

        public string? SalesRepName { get; set; }

        public int? SalesNum { get; set; }

        public string? SalesDocNumber { get; set; }

        public int? ShipId { get; set; }

        public string? PayeeName { get; set; }

        public DateOnly? ShipDate { get; set; }

        public decimal? SalesTotal { get; set; }

        public decimal? CountableTotal { get; set; }

        public decimal? CostTotal { get; set; }

        public decimal? Margin { get; set; }
    }
}
