using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;

namespace KLS.Models
{
    /// <summary>Step 1. Upload one section's workbook and see what it would do.</summary>
    public class OpenBalancePreviewReq
    {
        public IFormFile? ExcelFile { get; set; }

        public OpenBalanceSection Section { get; set; }
    }

    /// <summary>
    /// Step 2. Commit the previewed workbook. Carries only the token: the file
    /// on disk is the source of truth, not whatever the client last saw.
    /// </summary>
    public class OpenBalanceCommitReq
    {
        public string? UploadToken { get; set; }

        public OpenBalanceSection Section { get; set; }

        /// <summary>
        /// Set by the user ticking the acknowledgement in the dialog. Without
        /// it a Confirm-level finding refuses the import server-side, so the
        /// checkbox is a real control and not just UX.
        /// </summary>
        public bool Acknowledged { get; set; }
    }

    /// <summary>Unpost one section.</summary>
    public class OpenBalanceSectionReq
    {
        public OpenBalanceSection Section { get; set; }
    }

    public class OpenBalancePreviewRes
    {
        public OpenBalanceSection Section { get; set; }

        public string SectionName { get; set; } = "";

        public string FileName { get; set; } = "";

        public string UploadToken { get; set; } = "";

        /// <summary>Rows in the uploaded file.</summary>
        public int RowCount { get; set; }

        /// <summary>Rows currently held for this section, for the replace message.</summary>
        public int PriorRowCount { get; set; }

        public decimal Total { get; set; }

        public int ErrorCount { get; set; }

        /// <summary>Worst severity across every row plus the file-level checks.</summary>
        public string Status { get; set; } = OpenBalanceSeverity.OK;

        /// <summary>True when a row is at Error: the import cannot proceed at all.</summary>
        public bool HasErrors { get; set; }

        /// <summary>
        /// True when the user must tick an acknowledgement first. Always paired
        /// with ConfirmMessage.
        /// </summary>
        public bool NeedsConfirm { get; set; }

        public string? ConfirmMessage { get; set; }

        public List<OpenBalanceExcelRow> Rows { get; set; } = new();
    }

    /// <summary>One card on the screen.</summary>
    public class OpenBalanceCard
    {
        public OpenBalanceSection Section { get; set; }

        public string SectionName { get; set; } = "";

        public string Unit { get; set; } = "";

        public int RowCount { get; set; }

        public decimal? SectionTotal { get; set; }

        public DateTime? LastImportedAt { get; set; }

        public bool IsPosted { get; set; }

        public DateTime? PostedAt { get; set; }

        public decimal? TrialBalance { get; set; }

        public bool HasTrialBalanceRow { get; set; }

        public decimal? Variance { get; set; }

        /// <summary>OK / Warning. Never Error: reconciliation does not block (D3).</summary>
        public string Status { get; set; } = OpenBalanceSeverity.OK;

        /// <summary>Plain-language variance line for the card, or null when it ties.</summary>
        public string? StatusMessage { get; set; }
    }

    /// <summary>The whole screen in one response.</summary>
    public class OpenBalanceStatusRes
    {
        public DateTime? AsOfDate { get; set; }

        public List<OpenBalanceCard> Cards { get; set; } = new();

        /// <summary>The @OBE plug: the net of everything, for the accountant to clear later.</summary>
        public decimal? ObeBalance { get; set; }

        /// <summary>True when at least one section does not tie.</summary>
        public bool HasVariance { get; set; }

        /// <summary>The banner. Null when everything ties.</summary>
        public string? VarianceMessage { get; set; }
    }

    /// <summary>Result of a Save and Import.</summary>
    public class OpenBalanceImportRes
    {
        public OpenBalanceSection Section { get; set; }

        public int RowCount { get; set; }

        public int PriorRowCount { get; set; }

        /// <summary>The refreshed screen, so one round trip both acts and repaints.</summary>
        public OpenBalanceStatusRes Status { get; set; } = new();
    }
}
