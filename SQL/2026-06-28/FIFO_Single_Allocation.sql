SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-06-28: Three changes (whole SP is gated by ITEM_USE_EXPIRYDATE -> no-op in KLS_2026,
-- active only on FIFO-on DBs e.g. GlobalTaste):
--   (1) ShipDate netting widened "= @TodayDate" -> ">= @TodayDate": subtract ALL forward
--       commitments (today + future), not just today's. Fixes over-allocation when a sale is
--       picked today but ships later (its hold still draws from today's opening). Base stays
--       Item.TodayOpenInventory (yesterday's close = today's opening -- the stable anchor used to
--       back-track which purchase lots make up the current on-hand).
--   (2) FIFO COST is no longer stored: margin now uses RecentCost (Sales_CalcMargin) and reports
--       use real @COGS, so the weighted FIFOCost is dead weight. The @FIFOCost compute is retired
--       (commented). FIFOHistory (the batch/expiry reservation string) is unchanged.
--   (3) The FIFOCost column is REPURPOSED as the allocation STATUS code:
--         1=ALLOCATED  2=NO_STOCK  3=NO_HISTORY  4=PARTIAL  5=NO_SHIP   (NULL = not evaluated)
--       Written at every outcome for visibility / re-allocate. FIFOHistory IS NULL stays the alloc
--       gate, so failed lines (status 2/3/5, FIFOHistory still NULL) are re-attempted when the
--       underlying data is fixed (stock arrives, purchase added, qty set).
DROP PROCEDURE IF EXISTS [dbo].[FIFO_Single_Allocation]
GO
CREATE PROCEDURE [dbo].[FIFO_Single_Allocation] -- EXEC FIFO_Single_Allocation @SalesId=70693
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ITEM_USE_EXPIRYDATE BIT;
    SELECT @ITEM_USE_EXPIRYDATE = SettingValue
    FROM SystemSetting
    WHERE SettingKey = 'ITEM_USE_EXPIRYDATE';
    -- Exit if FIFO by expiry date is disabled
    IF @ITEM_USE_EXPIRYDATE = 0
        RETURN;
    -- Temporary purchase history table
    CREATE TABLE #Purchase
    (
        PurchaseDetailId INT,
        ItemId INT,
        ArrivalDate DATE,
        ExpiryDate DATE,
        TotalCost DECIMAL(18,2),
        CumQty DECIMAL(18,6),
        RowNum INT
    );
    -- FIFO allocation result table
    CREATE TABLE #MyTable
    (
        PurchaseDetailId INT,
        ArrivalDate DATE,
        AllocateQty DECIMAL(18,6),
        Cost DECIMAL(18,2),
        ExpiryDate NVARCHAR(50)
    );
    -- Variables for current sales detail row
    DECLARE @SalesDetailId INT;
    DECLARE @ItemId INT;
    DECLARE @BaseShipQty DECIMAL(18,6);
    -- SalesDetail rows to be processed
    CREATE TABLE #SalesDetail
    (
        RowNum INT IDENTITY(1,1),
        SalesDetailId INT,
        ItemId INT,
        BaseShipQty DECIMAL(18,6)
    );
    -- Load SalesDetail rows without FIFO allocation
    INSERT INTO #SalesDetail (SalesDetailId, ItemId, BaseShipQty)
    SELECT SalesDetailId, ItemId, BaseShipQty
    FROM SalesDetail
    WHERE SalesId = @SalesId AND ItemId IS NOT NULL
      AND FIFOHistory IS NULL
    ORDER BY SalesDetailId;
    DECLARE @RowNum INT = 1;
    DECLARE @MaxRow INT;
    SELECT @MaxRow = COUNT(*) FROM #SalesDetail;
    -- Process each SalesDetail row
    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT
            @SalesDetailId = SalesDetailId,
            @ItemId = ItemId,
            @BaseShipQty = BaseShipQty
        FROM #SalesDetail
        WHERE RowNum = @RowNum;
        -- 2026-06-28: nothing to ship on this line -> status NO_SHIP(5). FIFOHistory left NULL.
        IF ISNULL(@BaseShipQty, 0) = 0
        BEGIN
            UPDATE SalesDetail SET FIFOCost = 5 WHERE SalesDetailId = @SalesDetailId;
            SET @RowNum += 1;
            CONTINUE;
        END;
        -- Clear temp tables
        DELETE FROM #Purchase;
        DELETE FROM #MyTable;
        -- Load purchase history ordered for FIFO calculation
        ;WITH Ordered AS
        (
            SELECT
                PurchaseDetailId,
                ItemId,
                ArrivalDate,
                ExpiryDate,
                TotalCost,
                SUM(BaseReceiveQty) OVER (
                    ORDER BY ArrivalDate DESC, PurchaseNumber DESC, PurchaseDetailId DESC
                ) AS CumQty,
                ROW_NUMBER() OVER (
                    ORDER BY ArrivalDate DESC, PurchaseNumber DESC, PurchaseDetailId DESC
                ) AS RowNum
            FROM View_PurchaseHistory
            WHERE ItemId = @ItemId
        )
        INSERT INTO #Purchase
        SELECT *
        FROM Ordered;
        -- Skip if no purchase history exists
        IF NOT EXISTS (SELECT 1 FROM #Purchase)
        BEGIN
            -- 2026-06-28: item never purchased / no cost basis -> status NO_HISTORY(3) (FIFOHistory NULL -> retried later)
            UPDATE SalesDetail SET FIFOCost = 3 WHERE SalesDetailId = @SalesDetailId;
            SET @RowNum += 1;
            CONTINUE;
        END;
        -- Get starting inventory for item (yesterday's close = today's opening; the stable anchor)
        DECLARE @StartingInventory DECIMAL(18,6);
        SELECT @StartingInventory = TodayOpenInventory
        FROM Item
        WHERE ItemId = @ItemId;
        -- Normalize starting inventory
        IF @StartingInventory IS NULL OR @StartingInventory < 0
            SET @StartingInventory = 0;
        -- Subtract all forward-committed already-allocated qty for this item.
        -- 2026-06-28: widened the window from "= @TodayDate" (today only) to ">= @TodayDate"
        -- (today AND future). A sale picked today but shipping later still draws from today's
        -- opening, so its hold must net out here -- otherwise the same units get double-allocated.
        DECLARE @TodayDate DATE = CAST(GETDATE() AS DATE);
        DECLARE @TotalFIFOQty DECIMAL(18,6);
        SELECT @TotalFIFOQty = ISNULL(SUM(sd.BaseShipQty), 0)
        FROM Sales s
        INNER JOIN SalesDetail sd ON s.SalesId = sd.SalesId
        -- WHERE s.ShipDate = @TodayDate          -- retired 2026-06-28: only netted today's commitments
        WHERE s.ShipDate >= @TodayDate
          AND sd.ItemId = @ItemId
          AND sd.FIFOHistory IS NOT NULL;
        SET @StartingInventory -= @TotalFIFOQty;
        -- Skip if no inventory available
        IF @StartingInventory <= 0
        BEGIN
            -- 2026-06-28: out of stock after netting forward commitments -> status NO_STOCK(2)
            UPDATE SalesDetail SET FIFOCost = 2 WHERE SalesDetailId = @SalesDetailId;
            SET @RowNum += 1;
            CONTINUE;
        END;
        -- Determine starting FIFO row
        DECLARE @CurRow INT;
        DECLARE @PrevRowCumQty DECIMAL(18,6);
        SELECT TOP (1) @CurRow = RowNum
        FROM #Purchase
        WHERE CumQty >= @StartingInventory;
        SET @CurRow = ISNULL(@CurRow, 1);
        SELECT @PrevRowCumQty = CumQty
        FROM #Purchase
        WHERE RowNum = @CurRow - 1;
        IF @PrevRowCumQty IS NULL
            SET @PrevRowCumQty = 0;
        -- Initialize FIFO allocation
        DECLARE @QtyNeeded DECIMAL(18,6) = @BaseShipQty;
        DECLARE @AllocateQty DECIMAL(18,6);
        -- Allocate FIFO quantities
        WHILE @QtyNeeded > 0 AND @CurRow >= 1
        BEGIN
            SET @AllocateQty =
                CASE
                    WHEN @StartingInventory - @QtyNeeded > @PrevRowCumQty
                        THEN @QtyNeeded
                    ELSE @StartingInventory - @PrevRowCumQty
                END;
            INSERT INTO #MyTable (PurchaseDetailId, ArrivalDate, AllocateQty, Cost, ExpiryDate)
            SELECT
                PurchaseDetailId,
                ArrivalDate,
                @AllocateQty,
                TotalCost,
                ISNULL(CONVERT(VARCHAR, ExpiryDate, 101), 'No Date')
            FROM #Purchase
            WHERE RowNum = @CurRow;
            SET @StartingInventory -= @AllocateQty;
            SET @QtyNeeded -= @AllocateQty;
            SET @CurRow -= 1;
            SELECT @PrevRowCumQty = ISNULL(CumQty, 0)
            FROM #Purchase
            WHERE RowNum = @CurRow - 1;
        END;
        -- 2026-06-28: FIFO cost is no longer stored (margin = RecentCost, reports = @COGS).
        -- Retired weighted-cost compute kept for reference:
        -- DECLARE @FIFOCost DECIMAL(18,2);
        -- SELECT @FIFOCost =
        --     CASE WHEN SUM(AllocateQty) <> 0 THEN SUM(AllocateQty * Cost) / SUM(AllocateQty) ELSE 0 END
        -- FROM #MyTable;
        -- Build FIFO history string (the batch/expiry reservation -- still written)
        DECLARE @FIFOHistory NVARCHAR(MAX);
        SELECT @FIFOHistory =
            STRING_AGG(
                CAST(PurchaseDetailId AS NVARCHAR) + '@' +
                CAST(AllocateQty AS NVARCHAR) + '@' +
                CAST(ExpiryDate AS NVARCHAR),
                ', '
            ) --WITHIN GROUP (ORDER BY ArrivalDate ASC)
        FROM #MyTable;
        -- 2026-06-28: outcome status -> PARTIAL(4) if we couldn't fully cover the line, else ALLOCATED(1)
        DECLARE @Status INT = CASE WHEN @QtyNeeded > 0 THEN 4 ELSE 1 END;
        -- Update SalesDetail: FIFOHistory keeps the batch reservation; FIFOCost now carries the
        -- allocation STATUS code (not a cost).
        UPDATE SalesDetail
        SET
            -- FIFOCost = @FIFOCost,          -- retired 2026-06-28: cost no longer stored here
            FIFOCost = @Status,
            FIFOHistory = @FIFOHistory
        WHERE SalesDetailId = @SalesDetailId;
        -- Move to next SalesDetail row
        SET @RowNum += 1;
    END;
    -- Cleanup temp tables
    DROP TABLE #Purchase;
    DROP TABLE #MyTable;
    DROP TABLE #SalesDetail;
    -- Recalculate sales margin
    EXEC [Sales_CalcMargin] @SalesId;
END
GO
