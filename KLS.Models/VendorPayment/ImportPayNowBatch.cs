using System;
using System.Collections.Generic;

namespace KLS.Models
{
    /// <summary>
    /// One batch of the workbook. One batch becomes exactly one VendorPayment.
    /// </summary>
    public class ImportPayNowBatch
    {
        /// <summary>Null when the spreadsheet left the Batch cell blank. Always an errored batch.</summary>
        public int? Batch { get; set; }

        public int? PayeeId { get; set; }

        /// <summary>Vendor name as resolved from the database, not as typed in the spreadsheet.</summary>
        public string? PayeeName { get; set; }

        public DateTime? PaymentDate { get; set; }

        public string? PmtRefNum { get; set; }

        public DateTime? BankDate { get; set; }

        /// <summary>Sum of the batch's line amounts. This is the payment amount.</summary>
        public decimal Amount { get; set; }

        /// <summary>True when BankDate is present: the payment will be created locked and cannot be edited afterwards.</summary>
        public bool IsLocked { get; set; }

        /// <summary>"Ok" | "Warning" | "Error" -- the worst status among this batch's rows.</summary>
        public string Status { get; set; } = ImportPayNowStatus.Ok;

        public List<string> Messages { get; set; } = new();

        public List<ImportPayNowRow> Rows { get; set; } = new();
    }
}
