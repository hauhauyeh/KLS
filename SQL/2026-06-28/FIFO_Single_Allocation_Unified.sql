SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-06-28: UNIFIED FIFO single-line allocator. Consolidates FIFO_Single_Allocation (final/pick)
-- and FIFO_Single_Allocation_OrderStage (order estimate) -- which were byte-identical except the
-- column set and the final margin recalc -- into one SP parameterized by @Stage:
--     @Stage = 'final'  -> reads/writes FIFOHistory / FIFOCost  + recomputes margin (Sales_CalcMargin)
--     @Stage = 'order'  -> reads/writes FIFOHistoryOrder / FIFOCostOrder (no margin recalc; it's the estimate)
-- No column-name dynamic SQL: gate/netting use a combined @Stage predicate, and the writes use
-- CASE so each statement touches only the stage's columns (the other column keeps its value).
-- FIFOCost / FIFOCostOrder carry the allocation STATUS (1=ALLOCATED 2=NO_STOCK 3=NO_HISTORY
-- 4=PARTIAL 5=NO_SHIP; NULL=not evaluated), NOT a cost (margin uses RecentCost; reports use @COGS).
-- FIFOHistory(Order) keeps the batch/expiry reservation string; its NULL stays the alloc gate.
-- Base = Item.TodayOpenInventory (yesterday's close = today's opening); forward commitments
-- (ShipDate >= today) net out. Whole SP gated by ITEM_USE_EXPIRYDATE (no-op when FIFO off).
-- The two old SPs are KEPT (not deleted); callers can switch to this incrementally.
DROP PROCEDURE IF EXISTS [dbo].[FIFO_Single_Allocation_Unified]
GO
CREATE PROCEDURE [dbo].[FIFO_Single_Allocation_Unified] -- EXEC FIFO_Single_Allocation_Unified @SalesId=70693,@Stage='final'
-- EXEC FIFO_Single_Allocation_Unified @SalesId=70693,@Stage='order'
    @SalesId INT,
    @Stage   VARCHAR(10) = 'final'   -- 'final' (pick/COGS-equivalent) | 'order' (estimate)
AS
BEGIN
    SET NOCOUNT ON;
    -- Validate @Stage so a typo can't silently run a no-op.
    IF @Stage NOT IN ('final', 'order')
        THROW 50030, 'Invalid @Stage. Use ''final'' or ''order''.', 1;

    DECLARE @ITEM_USE_EXPIRYDATE BIT;
    SELECT @ITEM_USE_EXPIRYDATE = SettingValue
    FROM SystemSetting
    WHERE SettingKey = 'ITEM_USE_EXPIRYDATE';
    IF @ITEM_USE_EXPIRYDATE = 0
        RETURN;

    CREATE TABLE #Purchase
    (
        PurchaseDetailId INT, ItemId INT, ArrivalDate DATE, ExpiryDate DATE,
        TotalCost DECIMAL(18,2), CumQty DECIMAL(18,6), RowNum INT
    );
    CREATE TABLE #MyTable
    (
        PurchaseDetailId INT, ArrivalDate DATE, AllocateQty DECIMAL(18,6),
        Cost DECIMAL(18,2), ExpiryDate NVARCHAR(50)
    );
    DECLARE @SalesDetailId INT, @ItemId INT, @BaseShipQty DECIMAL(18,6);
    CREATE TABLE #SalesDetail
    (
        RowNum INT IDENTITY(1,1), SalesDetailId INT, ItemId INT, BaseShipQty DECIMAL(18,6)
    );
    -- Load lines not yet allocated for THIS stage (combined predicate -> no IF branch).
    INSERT INTO #SalesDetail (SalesDetailId, ItemId, BaseShipQty)
    SELECT SalesDetailId, ItemId, BaseShipQty
    FROM SalesDetail
    WHERE SalesId = @SalesId AND ItemId IS NOT NULL
      AND ((@Stage = 'order' AND FIFOHistoryOrder IS NULL)
        OR (@Stage = 'final' AND FIFOHistory      IS NULL))
    ORDER BY SalesDetailId;

    DECLARE @RowNum INT = 1, @MaxRow INT;
    SELECT @MaxRow = COUNT(*) FROM #SalesDetail;
    DECLARE @TodayDate DATE = CAST(GETDATE() AS DATE);

    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT @SalesDetailId = SalesDetailId, @ItemId = ItemId, @BaseShipQty = BaseShipQty
        FROM #SalesDetail WHERE RowNum = @RowNum;

        -- nothing to ship -> NO_SHIP(5)
        IF ISNULL(@BaseShipQty, 0) = 0
        BEGIN
            UPDATE SalesDetail
            SET FIFOCost      = CASE WHEN @Stage = 'final' THEN 5 ELSE FIFOCost END,
                FIFOCostOrder = CASE WHEN @Stage = 'order' THEN 5 ELSE FIFOCostOrder END
            WHERE SalesDetailId = @SalesDetailId;
            SET @RowNum += 1; CONTINUE;
        END;

        DELETE FROM #Purchase; DELETE FROM #MyTable;
        ;WITH Ordered AS
        (
            SELECT PurchaseDetailId, ItemId, ArrivalDate, ExpiryDate, TotalCost,
                SUM(BaseReceiveQty) OVER (ORDER BY ArrivalDate DESC, PurchaseNumber DESC, PurchaseDetailId DESC) AS CumQty,
                ROW_NUMBER()        OVER (ORDER BY ArrivalDate DESC, PurchaseNumber DESC, PurchaseDetailId DESC) AS RowNum
            FROM View_PurchaseHistory WHERE ItemId = @ItemId
        )
        INSERT INTO #Purchase SELECT * FROM Ordered;

        -- no purchase history -> NO_HISTORY(3)
        IF NOT EXISTS (SELECT 1 FROM #Purchase)
        BEGIN
            UPDATE SalesDetail
            SET FIFOCost      = CASE WHEN @Stage = 'final' THEN 3 ELSE FIFOCost END,
                FIFOCostOrder = CASE WHEN @Stage = 'order' THEN 3 ELSE FIFOCostOrder END
            WHERE SalesDetailId = @SalesDetailId;
            SET @RowNum += 1; CONTINUE;
        END;

        -- Base = today's opening (yesterday's close); the stable anchor for positioning the lots.
        DECLARE @StartingInventory DECIMAL(18,6);
        SELECT @StartingInventory = TodayOpenInventory FROM Item WHERE ItemId = @ItemId;
        IF @StartingInventory IS NULL OR @StartingInventory < 0
            SET @StartingInventory = 0;

        -- Net ALL forward commitments (today + future) for this stage (ShipDate >= today).
        DECLARE @TotalFIFOQty DECIMAL(18,6);
        SELECT @TotalFIFOQty = ISNULL(SUM(sd.BaseShipQty), 0)
        FROM Sales s INNER JOIN SalesDetail sd ON s.SalesId = sd.SalesId
        WHERE s.ShipDate >= @TodayDate AND sd.ItemId = @ItemId
          AND ((@Stage = 'order' AND sd.FIFOHistoryOrder IS NOT NULL)
            OR (@Stage = 'final' AND sd.FIFOHistory      IS NOT NULL));
        SET @StartingInventory -= @TotalFIFOQty;

        -- out of stock -> NO_STOCK(2)
        IF @StartingInventory <= 0
        BEGIN
            UPDATE SalesDetail
            SET FIFOCost      = CASE WHEN @Stage = 'final' THEN 2 ELSE FIFOCost END,
                FIFOCostOrder = CASE WHEN @Stage = 'order' THEN 2 ELSE FIFOCostOrder END
            WHERE SalesDetailId = @SalesDetailId;
            SET @RowNum += 1; CONTINUE;
        END;

        -- Position the FIFO frontier and allocate (unchanged core logic; no stage dependency).
        DECLARE @CurRow INT, @PrevRowCumQty DECIMAL(18,6);
        SELECT TOP (1) @CurRow = RowNum FROM #Purchase WHERE CumQty >= @StartingInventory;
        SET @CurRow = ISNULL(@CurRow, 1);
        SELECT @PrevRowCumQty = CumQty FROM #Purchase WHERE RowNum = @CurRow - 1;
        IF @PrevRowCumQty IS NULL SET @PrevRowCumQty = 0;

        DECLARE @QtyNeeded DECIMAL(18,6) = @BaseShipQty, @AllocateQty DECIMAL(18,6);
        WHILE @QtyNeeded > 0 AND @CurRow >= 1
        BEGIN
            SET @AllocateQty = CASE WHEN @StartingInventory - @QtyNeeded > @PrevRowCumQty
                                    THEN @QtyNeeded ELSE @StartingInventory - @PrevRowCumQty END;
            INSERT INTO #MyTable (PurchaseDetailId, ArrivalDate, AllocateQty, Cost, ExpiryDate)
            SELECT PurchaseDetailId, ArrivalDate, @AllocateQty, TotalCost,
                   ISNULL(CONVERT(VARCHAR, ExpiryDate, 101), 'No Date')
            FROM #Purchase WHERE RowNum = @CurRow;
            SET @StartingInventory -= @AllocateQty;
            SET @QtyNeeded -= @AllocateQty;
            SET @CurRow -= 1;
            SELECT @PrevRowCumQty = ISNULL(CumQty, 0) FROM #Purchase WHERE RowNum = @CurRow - 1;
        END;

        -- Reservation string (cost is no longer stored -- margin=RecentCost, reports=@COGS).
        DECLARE @FIFOHistory NVARCHAR(MAX);
        SELECT @FIFOHistory = STRING_AGG(
            CAST(PurchaseDetailId AS NVARCHAR) + '@' + CAST(AllocateQty AS NVARCHAR) + '@' + CAST(ExpiryDate AS NVARCHAR), ', ')
        FROM #MyTable;
        -- outcome: PARTIAL(4) if not fully covered, else ALLOCATED(1)
        DECLARE @Status INT = CASE WHEN @QtyNeeded > 0 THEN 4 ELSE 1 END;

        -- Write status + reservation into THIS stage's columns (CASE keeps the other stage's intact).
        UPDATE SalesDetail
        SET FIFOCost         = CASE WHEN @Stage = 'final' THEN @Status      ELSE FIFOCost END,
            FIFOHistory      = CASE WHEN @Stage = 'final' THEN @FIFOHistory ELSE FIFOHistory END,
            FIFOCostOrder    = CASE WHEN @Stage = 'order' THEN @Status      ELSE FIFOCostOrder END,
            FIFOHistoryOrder = CASE WHEN @Stage = 'order' THEN @FIFOHistory ELSE FIFOHistoryOrder END
        WHERE SalesDetailId = @SalesDetailId;

        SET @RowNum += 1;
    END;

    DROP TABLE #Purchase; DROP TABLE #MyTable; DROP TABLE #SalesDetail;

    -- Final stage recomputes margin; order stage is just the estimate.
    IF @Stage = 'final'
        EXEC [Sales_CalcMargin] @SalesId;
END
GO
