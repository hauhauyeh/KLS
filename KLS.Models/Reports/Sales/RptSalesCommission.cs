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
