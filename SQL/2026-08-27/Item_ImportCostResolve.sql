-- ============================================================
-- Item_ImportCostResolve  (2026-08-27, NEW; v2 same day - plan item-import-cost-v2)
--
-- The ONE place that turns uploaded rows into resolved rows with a
-- status. Item_ImportCostPreview (read) and Item_ImportCost (write) both
-- call it, so what the user approves in the preview is exactly what the
-- import acts on.
--
-- Contract: the CALLER creates #ImportCostRows (see the CREATE TABLE
-- comment below) and this proc fills it.
--
-- @RowsJson: [{"RowNo":1,"Code":"APPFUJI","Description":"APPLES FUJI 88CT","Price":"47.80"}, ...]
--   Price stays TEXT until here so "MKT" reaches SQL verbatim.
--
-- v2 (2026-08-27): match key is ItemUnit.Barcode ONLY - the vendor's code
-- stored on the unit, exactly as the old system matched Item.BarcodeW.
-- No vendor, no mapping table, no ItemCode fallback.
--   v1 (same day) resolved via VendorItemCode(PayeeId, Code) then
--   Item.ItemCode; see Item_ImportCostResolve_live_baseline.sql.
--
-- One file row can match MORE than one unit (16 barcodes in MGP data are
-- shared by 2-3 units): every match becomes its own row (MatchNo 1..n),
-- all are updated - the old UPDATE ... WHERE BarcodeW = @code did the
-- same - and IsSharedBarcode = 1 makes it visible in the preview.
--
-- Status precedence (first match wins), per resolved row:
--   Invalid   blank code / duplicate code in file / blank, zero, negative
--             or non-numeric non-MKT price / product has no base unit
--   NotFound  no unit carries this barcode (item deleted counts as none)
--   Market    price text is MKT (skipped, never written)
--   Skipped   another file row already sets this product's cost: when two
--             rows resolve to units of the SAME item (cs + ea barcodes),
--             the base-unit row wins, then the lowest RowNo
--   Unchanged new base cost equals the live cost of this tier, to the cent
--   Update    everything else (inactive products included: a cost is not a sale)
--
-- Cost math (base unit basis, 2dp like ItemUnit_UpdateRecentCost):
--   NewBaseCost        = ROUND(Price * FactorToBase / MultipleToBase, 2)   of the MATCHED unit
--   ResolvedLandedCost = NewBaseCost + landed share   (Tier 1 only)
--   landed share       = RecentCost - RecentBaseCost of the BASE unit when both
--                        are non-NULL and the difference is > 0; else 0.
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Item_ImportCostResolve]
    -- Caller must first run:
    -- CREATE TABLE #ImportCostRows (
    --     RowNo INT NOT NULL, MatchNo INT NOT NULL DEFAULT 1, Code NVARCHAR(50) NULL, Description NVARCHAR(200) NULL, PriceText NVARCHAR(50) NULL,
    --     Price DECIMAL(18,4) NULL, IsMarket BIT NOT NULL DEFAULT 0,
    --     ItemId INT NULL, ItemUnitId INT NULL, ItemCode NVARCHAR(50) NULL, ItemName NVARCHAR(200) NULL, Unit NVARCHAR(50) NULL,
    --     IsSharedBarcode BIT NOT NULL DEFAULT 0, IsItemInactive BIT NOT NULL DEFAULT 0,
    --     FactorToBase DECIMAL(18,6) NULL, MultipleToBase INT NULL,
    --     NewBaseCost DECIMAL(18,4) NULL, CurrentCost DECIMAL(18,4) NULL, OtherCost DECIMAL(18,4) NULL,
    --     PendingCost DECIMAL(18,4) NULL, ResolvedLandedCost DECIMAL(18,4) NULL,
    --     Status NVARCHAR(20) NULL, Message NVARCHAR(400) NULL);
    -- EXEC dbo.Item_ImportCostResolve @Tier = 1, @RowsJson = N'[{"RowNo":1,"Code":"APPFUJI","Description":"APPLES FUJI 88CT","Price":"47.80"}]'

    @Tier     TINYINT,
    @RowsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Tier NOT IN (1, 2)
        THROW 51040, 'Tier must be 1 (pricing) or 2 (reference).', 1;

    IF OBJECT_ID('tempdb..#ImportCostRows') IS NULL
        THROW 51041, 'Item_ImportCostResolve requires the caller to create #ImportCostRows.', 1;

    -- 1. File rows
    DECLARE @File TABLE
    (
        RowNo       INT NOT NULL PRIMARY KEY,
        Code        NVARCHAR(50) NULL,
        Description NVARCHAR(200) NULL,
        PriceText   NVARCHAR(50) NULL
    );

    INSERT INTO @File (RowNo, Code, Description, PriceText)
    SELECT
        j.RowNo,
        NULLIF(LTRIM(RTRIM(j.Code)), ''),
        LEFT(LTRIM(RTRIM(j.Description)), 200),
        NULLIF(LTRIM(RTRIM(j.Price)), '')
    FROM OPENJSON(@RowsJson)
    WITH (
        RowNo       INT           '$.RowNo',
        Code        NVARCHAR(50)  '$.Code',
        Description NVARCHAR(200) '$.Description',
        Price       NVARCHAR(50)  '$.Price'
    ) j;

    -- 2. One resolved row per (file row x unit carrying that barcode); unmatched rows stay as one row.
    INSERT INTO #ImportCostRows
        (RowNo, MatchNo, Code, Description, PriceText, Price, IsMarket,
         ItemId, ItemUnitId, ItemCode, ItemName, Unit, IsSharedBarcode, IsItemInactive, FactorToBase, MultipleToBase)
    SELECT
        f.RowNo,
        ISNULL(ROW_NUMBER() OVER (PARTITION BY f.RowNo ORDER BY u.IsBaseUnit DESC, u.ItemUnitId), 1),
        f.Code,
        f.Description,
        f.PriceText,
        TRY_CONVERT(DECIMAL(18,4), f.PriceText),
        CASE WHEN UPPER(f.PriceText) = 'MKT' THEN 1 ELSE 0 END,
        i.ItemId,
        u.ItemUnitId,
        i.ItemCode,
        i.ItemName,
        u.Unit,
        CASE WHEN COUNT(u.ItemUnitId) OVER (PARTITION BY f.RowNo) > 1 THEN 1 ELSE 0 END,
        ISNULL(i.Inactive, 0),
        u.FactorToBase,
        u.MultipleToBase
    FROM @File f
    -- Units of deleted items are not candidates at all, so such a barcode
    -- yields NotFound instead of silently dropping the file row.
    LEFT JOIN dbo.ItemUnit u
        ON u.Barcode = f.Code
       AND f.Code IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.Item x WHERE x.ItemId = u.ItemId AND x.IsDeleted = 0)
    LEFT JOIN dbo.Item i
        ON i.ItemId = u.ItemId;

    -- 3. Cost math. Live/pending costs are read from the BASE unit so every row compares on the same basis.
    UPDATE r
    SET r.NewBaseCost = CASE
                            WHEN r.Price IS NULL THEN NULL
                            ELSE ROUND(r.Price * r.FactorToBase / NULLIF(ISNULL(NULLIF(r.MultipleToBase, 0), 1), 0), 2)
                        END,
        r.CurrentCost = CASE WHEN @Tier = 1 THEN bu.RecentBaseCost  ELSE bu.RecentBaseCost2 END,
        r.OtherCost   = CASE WHEN @Tier = 1 THEN bu.RecentBaseCost2 ELSE bu.RecentBaseCost  END,
        r.PendingCost = CASE WHEN @Tier = 1 THEN bu.PendingBaseCost ELSE bu.PendingBaseCost2 END
    FROM #ImportCostRows r
    INNER JOIN dbo.ItemUnit bu ON bu.ItemId = r.ItemId AND bu.IsBaseUnit = 1;

    -- Landed share (Tier 1 only): keep the existing freight/duty share when derivable.
    IF @Tier = 1
    BEGIN
        UPDATE r
        SET r.ResolvedLandedCost =
                r.NewBaseCost
              + CASE
                    WHEN bu.RecentCost IS NOT NULL AND bu.RecentBaseCost IS NOT NULL
                         AND bu.RecentCost - bu.RecentBaseCost > 0
                    THEN bu.RecentCost - bu.RecentBaseCost
                    ELSE 0
                END
        FROM #ImportCostRows r
        INNER JOIN dbo.ItemUnit bu ON bu.ItemId = r.ItemId AND bu.IsBaseUnit = 1
        WHERE r.NewBaseCost IS NOT NULL;
    END

    -- 4. Status, first match wins.
    --    dup  = same code more than once in the FILE
    --    win  = for rows resolving to the same item, the one that sets the cost (base unit, then lowest RowNo)
    ;WITH dup AS
    (
        SELECT Code, COUNT(*) AS CodeCount
        FROM @File
        WHERE Code IS NOT NULL
        GROUP BY Code
    ),
    win AS
    (
        SELECT r.RowNo, r.MatchNo,
               ROW_NUMBER() OVER (PARTITION BY r.ItemId ORDER BY CASE WHEN u.IsBaseUnit = 1 THEN 0 ELSE 1 END, r.RowNo, r.MatchNo) AS Rank
        FROM #ImportCostRows r
        INNER JOIN dbo.ItemUnit u ON u.ItemUnitId = r.ItemUnitId
        WHERE r.ItemId IS NOT NULL
          AND r.IsMarket = 0
          AND r.Price > 0
    )
    UPDATE r
    SET r.Status =
            CASE
                WHEN r.Code IS NULL                                              THEN 'Invalid'
                WHEN d.CodeCount > 1                                             THEN 'Invalid'
                WHEN r.IsMarket = 0 AND (r.Price IS NULL OR r.Price <= 0)        THEN 'Invalid'
                WHEN r.ItemId IS NOT NULL AND r.CurrentCost IS NULL
                     AND NOT EXISTS (SELECT 1 FROM dbo.ItemUnit b WHERE b.ItemId = r.ItemId AND b.IsBaseUnit = 1) THEN 'Invalid'
                WHEN r.ItemId IS NULL                                            THEN 'NotFound'
                WHEN r.IsMarket = 1                                              THEN 'Market'
                WHEN w.Rank > 1                                                  THEN 'Skipped'
                WHEN r.CurrentCost IS NOT NULL AND r.NewBaseCost = r.CurrentCost THEN 'Unchanged'
                ELSE 'Update'
            END,
        r.Message =
            CASE
                WHEN r.Code IS NULL                                              THEN 'Blank product code.'
                WHEN d.CodeCount > 1                                             THEN 'Duplicate product code in file.'
                WHEN r.IsMarket = 0 AND r.Price IS NULL                          THEN 'Price is not a number.'
                WHEN r.IsMarket = 0 AND r.Price <= 0                             THEN 'Price must be greater than zero.'
                WHEN r.ItemId IS NOT NULL AND r.CurrentCost IS NULL
                     AND NOT EXISTS (SELECT 1 FROM dbo.ItemUnit b WHERE b.ItemId = r.ItemId AND b.IsBaseUnit = 1) THEN 'Product has no base unit. Fix the product first.'
                WHEN r.ItemId IS NULL                                            THEN 'No unit has this barcode. Skipped.'
                WHEN r.IsMarket = 1                                              THEN 'Market price (MKT). Skipped.'
                WHEN w.Rank > 1                                                  THEN 'Another row in the file sets this product''s cost (base unit wins). Skipped.'
                WHEN r.CurrentCost IS NOT NULL AND r.NewBaseCost = r.CurrentCost THEN 'Same as current cost.'
                ELSE LTRIM(
                       CASE WHEN r.IsSharedBarcode = 1 THEN ' Shared barcode: every unit with this barcode is updated.' ELSE '' END
                     + CASE WHEN r.IsItemInactive = 1 THEN ' Product is inactive.' ELSE '' END
                     + CASE WHEN r.PendingCost IS NOT NULL THEN ' Replaces a pending cost of ' + CONVERT(NVARCHAR(30), r.PendingCost) + '.' ELSE '' END)
            END
    FROM #ImportCostRows r
    LEFT JOIN dup d ON d.Code = r.Code
    LEFT JOIN win w ON w.RowNo = r.RowNo AND w.MatchNo = r.MatchNo;

    UPDATE #ImportCostRows SET Message = NULL WHERE Message = '';
END
GO
