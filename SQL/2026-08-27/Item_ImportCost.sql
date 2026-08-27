-- ============================================================
-- Item_ImportCost  (2026-08-27, NEW; v2 same day, write)
-- Step 2 of the Import Cost screen: STAGE the resolved rows.
--
-- Writes ONLY the pending columns:
--   Tier 1 -> ItemUnit.PendingBaseCost
--   Tier 2 -> ItemUnit.PendingBaseCost2
-- on EVERY unit of each matched item, scaled per unit with the same
-- formula as ItemUnit_UpdateRecentCost:
--   ROUND(base * ISNULL(NULLIF(MultipleToBase,0),1) / NULLIF(FactorToBase,0), 2)
--
-- Live costs (RecentBaseCost / RecentCost / RecentBaseCost2) are NEVER
-- touched here; Item_ApplyPendingCost does that on the schedule day.
-- No journal, no RecalculationLog, no @INV: item master data only.
--
-- Rows with Status NotFound / Market / Skipped / Unchanged are skipped and
-- counted. Any Invalid row aborts (the service already blocks this; the
-- proc is the control).
--
-- v2: no @PayeeId, no VendorItemCode refresh, no per-unit detail rows
--     (ItemCostImportDetail dropped - "keep 2 tables"); + @NotInFileCount OUT.
--     Header + unit update are still one transaction.
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Item_ImportCost]
    -- DECLARE @id INT, @n INT, @m INT;
    -- EXEC dbo.Item_ImportCost @Tier = 1, @RowsJson = N'[...]', @EmpId = 1,
    --      @FileName = N'costs.csv', @EffectiveFrom = '2026-08-25', @EffectiveTo = '2026-08-27',
    --      @ImportId = @id OUTPUT, @UpdatedCount = @n OUTPUT, @NotInFileCount = @m OUTPUT;

    @Tier           TINYINT,
    @RowsJson       NVARCHAR(MAX),
    @EmpId          INT,
    @FileName       NVARCHAR(255),
    @EffectiveFrom  DATE = NULL,
    @EffectiveTo    DATE = NULL,
    @ImportId       INT OUTPUT,
    @UpdatedCount   INT OUTPUT,
    @NotInFileCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ImportId = NULL;
    SET @UpdatedCount = 0;
    SET @NotInFileCount = 0;

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

    DECLARE @FileRows      INT = (SELECT COUNT(DISTINCT RowNo) FROM #ImportCostRows);
    DECLARE @InvalidCount  INT = (SELECT COUNT(*) FROM #ImportCostRows WHERE Status = 'Invalid');
    DECLARE @UpdateRows    INT = (SELECT COUNT(*) FROM #ImportCostRows WHERE Status = 'Update');
    DECLARE @NotFoundCount INT = (SELECT COUNT(*) FROM #ImportCostRows WHERE Status = 'NotFound');
    DECLARE @MarketCount   INT = (SELECT COUNT(*) FROM #ImportCostRows WHERE Status = 'Market');
    DECLARE @Msg           NVARCHAR(400);

    IF @FileRows = 0
        THROW 51043, 'The file has no product rows.', 1;

    IF @InvalidCount > 0
    BEGIN
        SET @Msg = CONCAT('The file has ', @InvalidCount, ' invalid row(s). Fix them and upload again.');
        THROW 51044, @Msg, 1;
    END

    IF @UpdateRows = 0
        THROW 51045, 'Nothing to import: no row changes a cost.', 1;

    SELECT @NotInFileCount = COUNT(*)
    FROM dbo.ItemUnit u
    INNER JOIN dbo.Item i ON i.ItemId = u.ItemId AND i.IsDeleted = 0
    WHERE NULLIF(u.Barcode, '') IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM #ImportCostRows r WHERE r.Code = u.Barcode);

    BEGIN TRAN;

        -- Header (PayeeId is NULL in v2: no vendor concept; UnmappedCount now carries NotFound)
        INSERT INTO dbo.ItemCostImport
            (PayeeId, Tier, FileName, EffectiveFrom, EffectiveTo, EmpId, FileRowCount, UpdatedCount, UnmappedCount, MarketCount)
        VALUES
            (NULL, @Tier, @FileName, @EffectiveFrom, @EffectiveTo, @EmpId, @FileRows, 0, @NotFoundCount, @MarketCount);

        SET @ImportId = SCOPE_IDENTITY();

        -- Stage on every unit of each 'Update' item, scaled from the base cost. Two plain branches; no dynamic SQL.
        IF @Tier = 1
        BEGIN
            UPDATE u
            SET u.PendingBaseCost = ROUND(r.NewBaseCost * ISNULL(NULLIF(u.MultipleToBase, 0), 1) / NULLIF(u.FactorToBase, 0), 2)
            FROM dbo.ItemUnit u
            INNER JOIN #ImportCostRows r ON r.ItemId = u.ItemId
            WHERE r.Status = 'Update';
        END
        ELSE
        BEGIN
            UPDATE u
            SET u.PendingBaseCost2 = ROUND(r.NewBaseCost * ISNULL(NULLIF(u.MultipleToBase, 0), 1) / NULLIF(u.FactorToBase, 0), 2)
            FROM dbo.ItemUnit u
            INNER JOIN #ImportCostRows r ON r.ItemId = u.ItemId
            WHERE r.Status = 'Update';
        END

        SET @UpdatedCount = @@ROWCOUNT;

        IF @UpdatedCount = 0
            THROW 51046, 'Import staged 0 units. Nothing was changed.', 1;

        UPDATE dbo.ItemCostImport
        SET UpdatedCount = @UpdatedCount
        WHERE ImportId = @ImportId;

    COMMIT;
END
GO
