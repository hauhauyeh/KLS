namespace KLS.Models.Reports
{
    public class RptSalesQuote
    {
        public Company? Company { get; set; }
        public SalesQuote? Quote { get; set; }
        public Payee? Customer { get; set; }
        public List<InvoiceDetail>? Details { get; set; }
        public string? SalesRepName { get; set; }

        public int? TotalItems => Details?
            .Where(d => d.ItemCode != null)
            .GroupBy(d => d.ItemCode).Count();

        public decimal? TotalCases => Details?
            .Where(d => d.LineType == "I")
            .Sum(d => d.BaseShipQty);

        public decimal? TotalWeight => Details?.Sum(d => d.ItemWeight);
    }
}
