using System;

namespace KLS.Models.Reports
{
    public class RptARAgingReq
    {
        public DateOnly? AsOfDate { get; set; }

        // 'DueDate' | 'InvoiceDate' — drives both AgeDays calc and bucket label.
        // SP defaults to 'DueDate' when null.
        public string? AgeBasis { get; set; }

        // Customer = ShipId (portal/admin AR identity model). Not BillId.
        public int? CustomerId { get; set; }

        public int? TermId { get; set; }

        public int? SalesRepId { get; set; }
    }
}
