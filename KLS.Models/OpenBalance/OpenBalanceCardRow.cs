using System;

namespace KLS.Models
{
    /// <summary>
    /// One row of [OpenBalance_Validate]: everything the screen knows about one
    /// section. Property names must match the proc's column names exactly.
    /// </summary>
    public class OpenBalanceCardRow
    {
        public string Section { get; set; } = "";

        public int GJNumber { get; set; }

        public int RowCount { get; set; }

        public decimal? SectionTotal { get; set; }

        public DateTime? LastImportedAt { get; set; }

        public bool IsPosted { get; set; }

        public DateTime? PostedAt { get; set; }

        public decimal? TotalDebitAmount { get; set; }

        public decimal? TotalCreditAmount { get; set; }

        /// <summary>The check figure from the Account sheet. Null for the Account section itself.</summary>
        public decimal? TrialBalance { get; set; }

        /// <summary>
        /// False when the Account sheet has no row for this control account.
        /// A missing target and a wrong target are different user errors and
        /// must not share a message.
        /// </summary>
        public bool HasTrialBalanceRow { get; set; }

        /// <summary>SectionTotal - TrialBalance. Null when there is nothing to compare.</summary>
        public decimal? Variance { get; set; }

        /// <summary>The @OBE plug. Populated on the Account row only.</summary>
        public decimal? ObeBalance { get; set; }
    }
}
