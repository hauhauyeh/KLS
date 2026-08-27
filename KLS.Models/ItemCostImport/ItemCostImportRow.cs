namespace KLS.Models
{
    /// <summary>
    /// One row of Item_ImportCostPreview: one per matched UNIT. A file line
    /// whose barcode is shared by several units produces MatchNo 1..n. Keyless.
    /// </summary>
    public class ItemCostImportRow
    {
        public int RowNo { get; set; }

        public int MatchNo { get; set; }

        public string? VendorCode { get; set; }

        public string? Description { get; set; }

        public string? PriceText { get; set; }

        public decimal? UnitPrice { get; set; }

        public int? ItemId { get; set; }

        public int? ItemUnitId { get; set; }

        public string? ItemCode { get; set; }

        public string? ItemName { get; set; }

        public string? Unit { get; set; }

        /// <summary>The barcode is carried by more than one unit; every one of them is updated.</summary>
        public bool IsSharedBarcode { get; set; }

        public decimal? NewBaseCost { get; set; }

        /// <summary>Live cost of the chosen tier on the base unit.</summary>
        public decimal? CurrentCost { get; set; }

        /// <summary>Live cost of the other tier, so both prices are visible side by side.</summary>
        public decimal? OtherCost { get; set; }

        /// <summary>A pending value already staged for this tier, if any (this import replaces it).</summary>
        public decimal? PendingCost { get; set; }

        /// <summary>Tier 1 only: new base cost plus the preserved landed share.</summary>
        public decimal? ResolvedLandedCost { get; set; }

        /// <summary>Update / Unchanged / NotFound / Market / Skipped / Invalid.</summary>
        public string Status { get; set; } = "";

        public string? Message { get; set; }
    }
}
