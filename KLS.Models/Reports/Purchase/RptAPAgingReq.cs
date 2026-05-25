using System;

namespace KLS.Models.Reports
{
    public class RptAPAgingReq
    {
        public DateOnly? AsOfDate { get; set; }

        // 'DueDate' | 'InvoiceDate' — drives both AgeDays calc and bucket label.
        // SP defaults to 'DueDate' when null.
        public string? AgeBasis { get; set; }

        public int? VendorId { get; set; }

        public int? TermId { get; set; }
    }
}
