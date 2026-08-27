-- ============================================================
-- Item_ImportCostPreview  (2026-08-27, NEW; v2 same day, read-only)
-- Step 1 of the Import Cost screen: resolve the uploaded rows and return
-- one row per matched unit with a status. Writes nothing.
-- All logic is in Item_ImportCostResolve; this proc only owns the temp
-- table and the output shape (ItemCostImportRow in C#).
-- v2: no @PayeeId (barcode-only match); + MatchNo, IsSharedBarcode;
--     @NotInFileCount OUTPUT = barcoded units of live items whose barcode
--     is not in the file (the old "Item Not In CSV" number).
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Item_ImportCostPreview]
    -- DECLARE @m INT;
    -- EXEC dbo.Item_ImportCostPreview @Tier = 1, @RowsJson = N'[{"RowNo":1,"Code":"APPFUJI","Description":"APPLES FUJI 88CT","Price":"47.80"}]', @NotInFileCount = @m OUTPUT

    @Tier           TINYINT,
    @RowsJson       NVARCHAR(MAX),
    @NotInFileCount INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #ImportCostRows (
        RowNo INT NOT NULL, MatchNo INT NOT NULL DEFAULT 1, Code NVARCHAR(50) NULL, Description NVARCHAR(200) NULL, PriceText NVARCHAR(50) NULL,
        Price DECIMAL(18,4) NULL, IsMarket BIT NOT NULL DEFAULT 0,
        ItemId INT NULL, ItemUnitId INT NULL, ItemCode NVARCHAR(50) NULL, ItemName NVARCHAR(200) NULL, Unit NVARCHAR(50) NULL,
        IsSharedBarcode BIT NOT NULL DEFAULT 0, IsItemInactive BIT NOT NULL DEFAULT 0,
        FactorToBase DECIMAL(18,6) NULL, MultipleToBase INT NULL,
        NewBaseCost DECIMAL(18,4) NULL, CurrentCost DECIMAL(18,4) NULL, OtherCost DECIMAL(18,4) NULL,
        PendingCost DECIMAL(18,4) NULL, ResolvedLandedCost DECIMAL(18,4) NULL,
        Status NVARCHAR(20) NULL, Message NVARCHAR(400) NULL);

    EXEC dbo.Item_ImportCostResolve @Tier = @Tier, @RowsJson = @RowsJson;

    -- Barcoded units (live items) whose barcode is not in this file.
    SELECT @NotInFileCount = COUNT(*)
    FROM dbo.ItemUnit u
    INNER JOIN dbo.Item i ON i.ItemId = u.ItemId AND i.IsDeleted = 0
    WHERE NULLIF(u.Barcode, '') IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM #ImportCostRows r WHERE r.Code = u.Barcode);

    SELECT
        RowNo,
        MatchNo,
        Code            AS VendorCode,
        Description,
        PriceText,
        Price           AS UnitPrice,
        ItemId,
        ItemUnitId,
        ItemCode,
        ItemName,
        Unit,
        IsSharedBarcode,
        NewBaseCost,
        CurrentCost,
        OtherCost,
        PendingCost,
        ResolvedLandedCost,
        Status,
        Message
    FROM #ImportCostRows
    ORDER BY RowNo, MatchNo;
END
GO
