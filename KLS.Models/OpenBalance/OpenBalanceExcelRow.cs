using System;

namespace KLS.Models
{
    /// <summary>
    /// One row of an opening balance workbook as returned by
    /// [OpenBalance_ImportPreview], enriched with the database values the
    /// importer will actually use. Property names must match the proc's
    /// column names exactly.
    ///
    /// One shape for all five sections: Key1/Key2/Amount mean slightly
    /// different things per section, which is what lets the preview grid and
    /// the dialog be written once.
    /// </summary>
    public class OpenBalanceExcelRow
    {
        /// <summary>1-based row number within the sheet, excluding the header.</summary>
        public int RowNo { get; set; }

        /// <summary>AccountCode / PayeeId / ItemCode.</summary>
        public string? Key1 { get; set; }

        /// <summary>InvoiceNumber (AR) or BillNumber (AP). Null elsewhere.</summary>
        public string? Key2 { get; set; }

        /// <summary>AccountId / PayeeId / ItemId, resolved from the database. Null when unresolved.</summary>
        public int? ResolvedId { get; set; }

        /// <summary>The database's name for the resolved row, so the user can eyeball the match.</summary>
        public string? ResolvedName { get; set; }

        public decimal? Qty { get; set; }

        public decimal? Price { get; set; }

        /// <summary>Balance (Account) / Amount (AR, AP, ARE) / TotalValue (Inventory).</summary>
        public decimal? Amount { get; set; }

        public string? Notes { get; set; }

        /// <summary>Error / Confirm / Warning / Info / OK. See OpenBalanceSeverity.</summary>
        public string Severity { get; set; } = OpenBalanceSeverity.OK;

        public string? Message { get; set; }
    }
}
