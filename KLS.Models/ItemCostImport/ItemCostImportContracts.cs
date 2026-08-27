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
    }

    public class ItemCostApplyResult
    {
        public int ApplyId { get; set; }

        public int UnitCount { get; set; }
    }
}
