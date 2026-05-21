using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptAPCheckRow
    {
        [Key]
        public int Rn { get; set; }

        public int? VendorPaymentId { get; set; }

        public DateOnly? PmtDate { get; set; }

        public string? PmtRefNum { get; set; }

        public decimal? PmtAmount { get; set; }

        public string? PayeeName { get; set; }

        public DateOnly? MailDate { get; set; }

        public DateOnly? BankDate { get; set; }

        public string? BankName { get; set; }

        public bool? IsVoid { get; set; }
    }

    public class RptCheckToBePrintedRow
    {
        [Key]
        public int Rn { get; set; }

        public int? PurchaseId { get; set; }

        public DateOnly? ArrivalDate { get; set; }

        public string? VendorDocNum { get; set; }

        public decimal? AmountDue { get; set; }

        public string? PmtTerm { get; set; }

        public DateOnly? DueDate { get; set; }

        public string? PayeeName { get; set; }

        public string? VendorPmtMethod { get; set; }
    }

    public class RptAPInvoiceRow
    {
        [Key]
        public int PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? PhoneDesc1 { get; set; }

        public string? Phone1 { get; set; }

        public decimal? Invoice60 { get; set; }

        public decimal? Invoice90 { get; set; }

        public decimal? InvoiceOver90 { get; set; }

        public decimal? PayeeTotalDue { get; set; }

        public int? TermId { get; set; }

        public string? Region { get; set; }

        public int? DueDays { get; set; }

        public decimal? Inv30 { get; set; }
    }
}
