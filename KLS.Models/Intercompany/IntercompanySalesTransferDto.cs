namespace KLS.Models.Intercompany
{
    public class IntercompanySalesTransferTargetDto
    {
        public string TargetCode { get; set; } = string.Empty;

        public string DisplayName { get; set; } = string.Empty;
    }

    public class IntercompanySalesTransferPreviewDto
    {
        public string TargetCode { get; set; } = string.Empty;

        public string SourceDatabaseName { get; set; } = string.Empty;

        public string TargetDatabaseName { get; set; } = string.Empty;

        public DateOnly FromShipDate { get; set; }

        public DateOnly ToShipDate { get; set; }

        public int EligibleTargetSalesCount { get; set; }

        public int SkippedTransferredSalesCount { get; set; }

        public int ItemLineCount { get; set; }

        public int GroupedLineCount { get; set; }

        public int EstimatedSourceSalesCount { get; set; }

        public decimal TotalQty { get; set; }

        public decimal TotalAmount { get; set; }

        public bool HasBlockers => Checks.Any(c => c.IsBlocker && c.CountValue > 0);

        public int BlockerCount => Checks.Where(c => c.IsBlocker).Sum(c => c.CountValue);

        public List<IntercompanySalesTransferCheckDto> Checks { get; set; } = new();

        public List<IntercompanySalesTransferPreviewRowDto> Rows { get; set; } = new();
    }

    public class IntercompanySalesTransferCheckDto
    {
        public string CheckName { get; set; } = string.Empty;

        public int CountValue { get; set; }

        public bool IsBlocker { get; set; }
    }

    public class IntercompanySalesTransferPreviewRowDto
    {
        public string RowType { get; set; } = string.Empty;

        public int? TargetSalesId { get; set; }

        public int? TargetSalesNumber { get; set; }

        public string? TargetSalesDocNumber { get; set; }

        public DateOnly? TargetShipDate { get; set; }

        public int? TargetStageId { get; set; }

        public int? ItemId { get; set; }

        public int? ItemUnitId { get; set; }

        public string? SourceValue { get; set; }

        public string? TargetValue { get; set; }

        public bool IsBlocker { get; set; }

        public string? Message { get; set; }
    }

    public class IntercompanySalesTransferCreateReq
    {
        public string TargetCode { get; set; } = string.Empty;

        public DateOnly FromShipDate { get; set; }

        public DateOnly ToShipDate { get; set; }
    }

    public class IntercompanySalesTransferCreateResultDto
    {
        public string TargetCode { get; set; } = string.Empty;

        public string SourceDatabaseName { get; set; } = string.Empty;

        public string TargetDatabaseName { get; set; } = string.Empty;

        public int BatchId { get; set; }

        public int SourceSalesCount { get; set; }

        public int TargetSalesCount { get; set; }

        public int LineCount { get; set; }

        public decimal TotalQty { get; set; }

        public decimal TotalAmount { get; set; }

        public List<IntercompanySalesTransferCreatedSalesDto> CreatedSales { get; set; } = new();
    }

    public class IntercompanySalesTransferCreatedSalesDto
    {
        public int SourceSalesId { get; set; }

        public int? SourceSalesNumber { get; set; }

        public DateOnly ShipDate { get; set; }

        public int TargetSalesCount { get; set; }

        public int LineCount { get; set; }

        public decimal TotalQty { get; set; }

        public decimal TotalAmount { get; set; }
    }
}
