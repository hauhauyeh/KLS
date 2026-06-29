CREATE PROCEDURE [dbo].[FIFO_Single_Allocation_OrderStage]
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
            SET @RowNum += 1;
            CONTINUE;
        END;
        -- Get starting inventory for item
        DECLARE @StartingInventory DECIMAL(18,6);
        SELECT @StartingInventory = TodayOpenInventory
        FROM Item
        WHERE ItemId = @ItemId;
        -- Normalize starting inventory
        IF @StartingInventory IS NULL OR @StartingInventory < 0
            SET @StartingInventory = 0;
        -- Subtract today's already FIFO allocated quantity
        DECLARE @TodayDate DATE = CAST(GETDATE() AS DATE);
        DECLARE @TotalFIFOQty DECIMAL(18,6);
        SELECT @TotalFIFOQty = ISNULL(SUM(sd.BaseShipQty), 0)
        FROM Sales s
        INNER JOIN SalesDetail sd ON s.SalesId = sd.SalesId
        WHERE s.ShipDate = @TodayDate
          AND sd.ItemId = @ItemId
          AND sd.FIFOHistoryOrder IS NOT NULL;
        SET @StartingInventory -= @TotalFIFOQty;
        -- Skip if no inventory available
        IF @StartingInventory <= 0
        BEGIN
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
        -- Calculate weighted FIFO cost
        DECLARE @FIFOCost DECIMAL(18,2);
        DECLARE @FIFOHistory NVARCHAR(MAX);
        SELECT @FIFOCost =
            CASE
                WHEN SUM(AllocateQty) <> 0
                    THEN SUM(AllocateQty * Cost) / SUM(AllocateQty)
                ELSE 0
            END
        FROM #MyTable;
        -- Build FIFO history string
        SELECT @FIFOHistory =
            STRING_AGG(
                CAST(PurchaseDetailId AS NVARCHAR) + '@' +
                CAST(AllocateQty AS NVARCHAR) + '@' +
                CAST(ExpiryDate AS NVARCHAR),
                ', '
            ) --WITHIN GROUP (ORDER BY ArrivalDate ASC)
        FROM #MyTable;
        -- Update SalesDetail FIFO fields
        UPDATE SalesDetail
        SET
            FIFOCostOrder = @FIFOCost,
            FIFOHistoryOrder = @FIFOHistory
        WHERE SalesDetailId = @SalesDetailId;
        -- Move to next SalesDetail row
        SET @RowNum += 1;
    END;
    -- Cleanup temp tables
    DROP TABLE #Purchase;
    DROP TABLE #MyTable;
    DROP TABLE #SalesDetail;
END;
