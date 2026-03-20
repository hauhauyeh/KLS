namespace KLS.Models.Reports
{
    public class RptSalesYearly
    {
        public List<RptSalesYearlyMonth>? YearlySales { get; set; }

        public List<RptSalesYearlyAccount>? Accounts { get; set; }

        public decimal? Y1Total { get; set; }

        public decimal? Y2Total { get; set; }

        public decimal? Y3Total { get; set; }

        public decimal? Y1Perc { get; set; }

        public decimal? Y2Perc { get; set; }
    }

    public class RptSalesYearlyMonth
    {
        public string? Month { get; set; }

        public decimal? Y1Total { get; set; }

        public decimal? Y2Total { get; set; }

        public decimal? Y3Total { get; set; }

        public decimal? Y1Perc { get; set; }

        public decimal? Y2Perc { get; set; }

        public List<RptSalesYearlyRow>? MonthlySales { get; set; }
    }

    public class RptSalesYearlyAccount
    {
        public string? AcctName { get; set; }

        public decimal? Y1Total { get; set; }

        public decimal? Y2Total { get; set; }

        public decimal? Y3Total { get; set; }
    }
}
