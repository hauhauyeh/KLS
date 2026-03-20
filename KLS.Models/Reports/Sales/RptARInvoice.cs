using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    // Flat row from Report_ARFromInvoice SP
    public class RptARInvoiceRow
    {
        [Key]
        public int PayeeId { get; set; }

        public string? Region { get; set; }

        public string? PayeeName { get; set; }

        public string? PhoneDesc1 { get; set; }

        public string? Phone1 { get; set; }

        public decimal? Inv0 { get; set; }

        public decimal? Inv30 { get; set; }

        public decimal? Invoice60 { get; set; }

        public decimal? Invoice90 { get; set; }

        public decimal? InvoiceOver90 { get; set; }

        public decimal? PayeeTotalDue { get; set; }

        public DateOnly? LastPmtDate { get; set; }

        public DateOnly? OwedSince { get; set; }

        public decimal? LastPmtAmt { get; set; }

        public decimal? UnAppliedAmt { get; set; }

        public int? TermId { get; set; }

        public int? DueDays { get; set; }
    }

    // Grouped response for API
    public class RptARInvoice
    {
        public List<RptARInvoiceTerm>? Terms { get; set; }

        public string? Sec1 { get; set; }

        public string? Sec2 { get; set; }

        public string? Sec3 { get; set; }

        public string? Sec4 { get; set; }

        public decimal? Inv30Total { get; set; }

        public decimal? Inv60Total { get; set; }

        public decimal? Inv90Total { get; set; }

        public decimal? InvOver90Total { get; set; }

        public decimal? ARTotal { get; set; }
    }

    public class RptARInvoiceTerm
    {
        public string? TermName { get; set; }

        public int? DueDays { get; set; }

        public bool IsFirstColumn { get; set; }

        public List<RptARInvoiceRow>? Payee { get; set; }
    }
}
