using Microsoft.AspNetCore.Http;
using System.Collections.Generic;

namespace KLS.Models
{
    /// <summary>Step 1. Upload a vendor price file (csv or xlsx) and see what it would stage.</summary>
    public class ItemCostImportPreviewReq
    {
        /// <summary>1 = pricing cost (RecentBaseCost / RecentCost), 2 = reference cost (RecentBaseCost2).</summary>
        public int Tier { get; set; } = 1;

        public IFormFile? File { get; set; }
    }

    /// <summary>
    /// Step 2. Commit the previewed file. Carries only the token: the file on
    /// disk is the source of truth, not whatever the client last saw.
    /// </summary>
    public class ItemCostImportTokenReq
    {
        public int Tier { get; set; } = 1;

        public string? UploadToken { get; set; }
    }

    /// <summary>One parsed line of the uploaded file. Price stays text so "MKT" reaches SQL verbatim.</summary>
    public record ItemCostImportFileRow(int RowNo, string Code, string Description, string Price);

    public class ItemCostImportPreviewRes
    {
        public int Tier { get; set; }

        public string UploadToken { get; set; } = "";

        public string FileName { get; set; } = "";

        /// <summary>yyyy-MM-dd, parsed from the vendor preamble ("08/25/26 thru 08/27/26") when present.</summary>
        public string? EffectiveFrom { get; set; }

        public string? EffectiveTo { get; set; }

        /// <summary>Lines in the file (a shared barcode can produce more than one preview row per line).</summary>
        public int FileRowCount { get; set; }

        public int UpdateCount { get; set; }

        public int UnchangedCount { get; set; }

        public int NotFoundCount { get; set; }

        public int MarketCount { get; set; }

        public int SkippedCount { get; set; }

        public int InvalidCount { get; set; }

        /// <summary>Barcoded units not in this file (the old "Item Not In CSV" number).</summary>
        public int NotInFileCount { get; set; }

        /// <summary>True when any row is Invalid: the import cannot proceed.</summary>
        public bool HasErrors { get; set; }

        public List<ItemCostImportRow> Rows { get; set; } = new();
    }

    /// <summary>Result of a commit. Costs are STAGED (pending), not live.</summary>
    public class ItemCostImportResult
    {
        public int ImportId { get; set; }

        /// <summary>Units that received a pending value (all units of every updated item).</summary>
        public int UpdatedUnitCount { get; set; }

        public int UpdateCount { get; set; }

        public int UnchangedCount { get; set; }

        public int NotFoundCount { get; set; }

        public int MarketCount { get; set; }

        public int SkippedCount { get; set; }

        public int NotInFileCount { get; set; }
    }

    public class ItemCostPendingStatusRes
    {
        public ItemCostPendingStatus Status { get; set; } = new();

        public List<ItemCostPendingImportRow> PendingImports { get; set; } = new();

        /// <summary>2026-08-29: orders waiting for reprice + last reprice run (plan-reprice-open-orders-v1 slice 5).</summary>
        public SalesRepriceStatus Reprice { get; set; } = new();
    }

    /// <summary>Single row from a plain SELECT (unmapped EF8 SqlQueryRaw type).</summary>
    public class SalesRepriceStatus
    {
        /// <summary>Sales.IsPricePending = 1 right now (includes skipped orders still flagged).</summary>
        public int PendingOrderCount { get; set; }

        public int? LastRepriceId { get; set; }

        public DateTime? LastRunAt { get; set; }

        public string? LastTriggeredBy { get; set; }

        public int? LastOrderCount { get; set; }

        public int? LastLineCount { get; set; }

        public int? LastSkippedCount { get; set; }

        public int? LastErrorCount { get; set; }
    }

    public class ItemCostApplyResult
    {
        public int ApplyId { get; set; }

        public int UnitCount { get; set; }

        /// <summary>2026-08-29: open orders re-priced right after the apply (plan-reprice-open-orders-v1 slice 4).</summary>
        public SalesRepriceResult? Reprice { get; set; }
    }

    /// <summary>One skipped / errored order from Sales_RepriceOpenOrders (Q4 list for the office).</summary>
    public class SalesRepriceSkippedRow
    {
        public int SalesId { get; set; }

        public int SalesNumber { get; set; }

        public int StageId { get; set; }

        public string Reason { get; set; } = string.Empty;
    }

    public class SalesRepriceResult
    {
        public int RepriceId { get; set; }

        public int OrderCount { get; set; }

        public int LineCount { get; set; }

        public int SkippedCount { get; set; }

        public int ErrorCount { get; set; }

        public List<SalesRepriceSkippedRow> Skipped { get; set; } = new();
    }
}
