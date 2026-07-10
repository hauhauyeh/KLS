using System;

namespace KLS.Models
{
    /// <summary>
    /// One row of the PayNow workbook as returned by [VendorPayment_ImportPreview],
    /// enriched with the database values the importer will actually use.
    /// Property names must match the proc's column names exactly.
    /// </summary>
    public class ImportPayNowExcelRow
    {
        public int RowNo { get; set; }

        // --- Raw Excel columns, in sheet order ---

        public DateTime? EnterDate { get; set; }

        public DateTime? ArrivalDate { get; set; }

        public int? PayeeId { get; set; }

        public string? PayeeName { get; set; }

        public string? PmtRefNum { get; set; }

        public string? AccountCode { get; set; }

        public string? AccountName { get; set; }

        public decimal? PmtAmount { get; set; }

        public string? Note { get; set; }

        public DateTime? BankDate { get; set; }

        /// <summary>Nullable here, NOT NULL in the importer. A blank cell is a validation error, not a crash.</summary>
        public int? Batch { get; set; }

        // --- Resolved from the database ---

        public string? DbPayeeName { get; set; }

        public int? DbAccountId { get; set; }

        public string? DbAccountName { get; set; }

        /// <summary>Number of Account rows sharing this AccountCode. >1 means the importer's scalar subquery would throw.</summary>
        public int AccountMatchCount { get; set; }

        // --- Batch-level aggregates, repeated on every row of the batch ---

        public int BatchRowCount { get; set; }

        public decimal? BatchTotal { get; set; }

        /// <summary>Distinct PayeeIds in this batch. >1 means the importer would post every line to one vendor, silently.</summary>
        public int BatchPayeeCount { get; set; }

        public bool IsDuplicate { get; set; }
    }
}
