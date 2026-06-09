using System;
using System.ComponentModel.DataAnnotations;

namespace KLS.Models.Reports
{
    public class RptARAgingRow
    {
        [Key]
        public int SalesId { get; set; }

        // Customer ShipId — AR aggregates by ShipId, not BillId. See
        // project_ar_ap_aging_architecture memory and the SP comments.
        public int? PayeeId { get; set; }

        public string? Customer { get; set; }

        public int? SalesNumber { get; set; }

        // Customer's PO reference (source column Sales.CustPONumber, aliased
        // as PONumber in the SP output).
        public string? PONumber { get; set; }

        public DateOnly? ShipDate { get; set; }

        public DateOnly? DueDate { get; set; }

        public string? Term { get; set; }

        // Customer-level, denormalized per row from Payee.LastPaymentDate /
        // LastPaymentAmount. Every row for the same customer carries the same
        // value. Frontend reads from the group's first row for the group
        // header; never rendered in per-invoice columns.
        public DateOnly? LastPaymentDate { get; set; }
        public decimal? LastPaymentAmount { get; set; }

        public decimal? OriginalAmount { get; set; }

        public decimal? OpenBalance { get; set; }

        public int? AgeDays { get; set; }

        public string? Bucket { get; set; }

        // Mirror columns: AmountDue lands in the row's own bucket, 0 in all
        // others. Frontend SUMs each column for subtotals/grand totals.
        public decimal? BucketCurrent { get; set; }
        public decimal? Bucket30 { get; set; }
        public decimal? Bucket60 { get; set; }
        public decimal? Bucket90 { get; set; }
        public decimal? BucketOver90 { get; set; }

        public bool? IsCredit { get; set; }
    }
}
