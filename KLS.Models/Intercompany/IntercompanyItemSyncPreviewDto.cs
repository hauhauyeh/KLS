namespace KLS.Models.Intercompany
{
    public class IntercompanyItemSyncPreviewDto
    {
        public string TargetCode { get; set; } = string.Empty;

        public string SourceDatabaseName { get; set; } = string.Empty;

        public string TargetDatabaseName { get; set; } = string.Empty;

        public int LocalOnlyStartId { get; set; }

        public bool HasBlockers => Checks.Any(c => c.IsBlocker && c.CountValue > 0);

        public int BlockerCount => Checks.Where(c => c.IsBlocker).Sum(c => c.CountValue);

        public List<IntercompanyItemSyncCheckDto> Checks { get; set; } = new();

        public List<IntercompanyItemSyncPreviewRowDto> Rows { get; set; } = new();
    }

    public class IntercompanyItemSyncRunDto
    {
        public string TargetCode { get; set; } = string.Empty;

        public string SourceDatabaseName { get; set; } = string.Empty;

        public string TargetDatabaseName { get; set; } = string.Empty;

        public int InsertedItemCount { get; set; }

        public int UpdatedItemCount { get; set; }

        public int InsertedItemUnitCount { get; set; }

        public int UpdatedItemUnitCount { get; set; }

        public int UpdatedBaseUnitCount { get; set; }
    }

    public class IntercompanyItemSyncTargetDto
    {
        public string TargetCode { get; set; } = string.Empty;

        public string DisplayName { get; set; } = string.Empty;
    }

    public class IntercompanyItemSyncRunReq
    {
        public string TargetCode { get; set; } = string.Empty;
    }

    public class IntercompanyItemSyncCheckDto
    {
        public string CheckName { get; set; } = string.Empty;

        public int CountValue { get; set; }

        public bool IsBlocker { get; set; }
    }

    public class IntercompanyItemSyncPreviewRowDto
    {
        public string RowType { get; set; } = string.Empty;

        public int? ItemId { get; set; }

        public int? ItemUnitId { get; set; }

        public string? SourceValue { get; set; }

        public string? TargetValue { get; set; }

        public bool IsBlocker { get; set; }

        public string? Message { get; set; }
    }
}
