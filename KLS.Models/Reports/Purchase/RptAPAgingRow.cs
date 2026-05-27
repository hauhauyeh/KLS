using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptAPAgingRow
    {
        [Key]
        public int PurchaseId { get; set; }

        public int? PayeeId { get; set; }

        public string? Vendor { get; set; }

        public int? PurchaseNumber { get; set; }

        public string? InvoiceNumber { get; set; }

        public string? ContainerNumber { get; set; }

        public DateOnly? InvoiceDate { get; set; }

        public DateOnly? DueDate { get; set; }

        public string? Term { get; set; }

        public string? DefaultPaymentMethod { get; set; }

        public decimal? OriginalAmount { get; set; }

        public decimal? OpenBalance { get; set; }

        public int? AgeDays { get; set; }

        public string? Bucket { get; set; }

        public decimal? BucketCurrent { get; set; }

        public decimal? Bucket30 { get; set; }

        public decimal? Bucket60 { get; set; }

        public decimal? Bucket90 { get; set; }

        public decimal? BucketOver90 { get; set; }

        public bool? IsCredit { get; set; }
    }
}
