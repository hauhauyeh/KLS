SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-06-28: order-stage FIFO reservation estimate (writes FIFOHistoryOrder; runs from
-- Sales_CalcTotal while the sale is at Order stage). Whole SP gated by ITEM_USE_EXPIRYDATE
-- (no-op in KLS_2026; active on FIFO-on DBs). Mirrors the final allocator:
--   (1) ShipDate netting widened "= @TodayDate" -> ">= @TodayDate" (net today AND future
--       commitments off today's opening).
--   (2) FIFOCostOrder REPURPOSED as the ORDER-STAGE allocation STATUS code (parallel to the
--       final allocator's FIFOCost): 1=ALLOCATED 2=NO_STOCK 3=NO_HISTORY 4=PARTIAL 5=NO_SHIP
--       (NULL = not evaluated). The old order-stage weighted cost is retired (margin uses
--       RecentCost; Sales_CalcMargin no longer reads FIFOCostOrder). FIFOHistoryOrder (the
--       reservation string, still read by Report_InvoiceDetail / Report_SalesQuote) is unchanged.
--       FIFOHistoryOrder IS NULL stays the order-stage gate, so failed lines (status 2/3/5) are
--       re-attempted when the data is fixed.
DROP PROCEDURE IF EXISTS [dbo].[FIFO_Single_Allocation_OrderStage]
GO
CREATE PROCEDURE [dbo].[FIFO_Single_Allocation_OrderStage] -- EXEC FIFO_Single_Allocation_OrderStage @SalesId=70693
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
    -- Load SalesDetail rows without an order-stage FIFO allocation yet
    INSERT INTO #SalesDetail (SalesDetailId, ItemId, BaseShipQty)
    SELECT SalesDetailId, ItemId, BaseShipQty
    FROM SalesDetail
    WHERE SalesId = @SalesId AND ItemId IS NOT NULL
      AND FIFOHistoryOrder IS NULL
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
        -- 2026-06-28: nothing to ship on this line -> status NO_SHIP(5). FIFOHistoryOrder left NULL.
        IF ISNULL(@BaseShipQty, 0) = 0
        BEGIN
            UPDATE SalesDetail SET FIFOCostOrder = 5 WHERE SalesDetailId = @SalesDetailId;
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
            -- 2026-06-28: item never purchased / no cost basis -> status NO_HISTORY(3) (FIFOHistoryOrder NULL -> retried later)
            UPDATE SalesDetail SET FIFOCostOrder = 3 WHERE SalesDetailId = @SalesDetailId;
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
        -- 2026-06-28: widened "= @TodayDate" -> ">= @TodayDate" (today AND future commitments).
        DECLARE @TodayDate DATE = CAST(GETDATE() AS DATE);
        DECLARE @TotalFIFOQty DECIMAL(18,6);
        SELECT @TotalFIFOQty = ISNULL(SUM(sd.BaseShipQty), 0)
        FROM Sales s
        INNER JOIN SalesDetail sd ON s.SalesId = sd.SalesId
        -- WHERE s.ShipDate = @TodayDate          -- retired 2026-06-28: only netted today's commitments
        WHERE s.ShipDate >= @TodayDate
          AND sd.ItemId = @ItemId
          AND sd.FIFOHistoryOrder IS NOT NULL;
        SET @StartingInventory -= @TotalFIFOQty;
        -- Skip if no inventory available
        IF @StartingInventory <= 0
        BEGIN
            -- 2026-06-28: out of stock after netting forward commitments -> status NO_STOCK(2)
            UPDATE SalesDetail SET FIFOCostOrder = 2 WHERE SalesDetailId = @SalesDetailId;
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
        -- 2026-06-28: order-stage FIFO cost no longer stored (margin = RecentCost). Retired compute:
        -- DECLARE @FIFOCost DECIMAL(18,2);
        -- SELECT @FIFOCost =
        --     CASE WHEN SUM(AllocateQty) <> 0 THEN SUM(AllocateQty * Cost) / SUM(AllocateQty) ELSE 0 END
        -- FROM #MyTable;
        -- Build FIFO history string (the order-stage reservation -- still written for the invoice/quote reports)
        DECLARE @FIFOHistory NVARCHAR(MAX);
        SELECT @FIFOHistory =
            STRING_AGG(
                CAST(PurchaseDetailId AS NVARCHAR) + '@' +
                CAST(AllocateQty AS NVARCHAR) + '@' +
                CAST(ExpiryDate AS NVARCHAR),
                ', '
            ) --WITHIN GROUP (ORDER BY ArrivalDate ASC)
        FROM #MyTable;
        -- 2026-06-28: outcome status -> PARTIAL(4) if not fully covered, else ALLOCATED(1)
        DECLARE @Status INT = CASE WHEN @QtyNeeded > 0 THEN 4 ELSE 1 END;
        -- Update SalesDetail order-stage fields: FIFOHistoryOrder keeps the reservation;
        -- FIFOCostOrder now carries the order-stage STATUS code (not a cost).
        UPDATE SalesDetail
        SET
            -- FIFOCostOrder = @FIFOCost,        -- retired 2026-06-28: cost replaced by status
            FIFOCostOrder = @Status,
            FIFOHistoryOrder = @FIFOHistory
        WHERE SalesDetailId = @SalesDetailId;
        -- Move to next SalesDetail row
        SET @RowNum += 1;
    END;
    -- Cleanup temp tables
    DROP TABLE #Purchase;
    DROP TABLE #MyTable;
    DROP TABLE #SalesDetail;
END
GO
