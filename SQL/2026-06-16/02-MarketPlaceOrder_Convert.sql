


CREATE PROCEDURE [dbo].[MarketPlaceOrder_Convert]
    @MarketAccountId INT,
    @OrderDate DATE,
    @EmpId INT,
    @NewSalesId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PayeeId INT;

    -- Step 1: Validate PayeeId on MarketAccount
    SELECT @PayeeId = PayeeId FROM MarketAccount WHERE MarketAccountId = @MarketAccountId;

    IF @PayeeId IS NULL
    BEGIN
        RAISERROR('MarketAccount does not have a PayeeId configured. Set a customer/payee on the marketplace account first.', 16, 1);
        RETURN;
    END

    -- Step 2: Collect qualifying orders (fully matched, not yet imported, has items)
    SELECT mo.MarketOrderId, mo.ExternalOrderId
    INTO #QualifyingOrders
    FROM MarketOrder mo
    WHERE mo.MarketAccountId = @MarketAccountId
      AND CAST(mo.OrderDate AS DATE) = @OrderDate
      AND mo.ImportedToErp = 0
      AND EXISTS (
        SELECT 1 FROM MarketOrderItem y
        WHERE y.MarketOrderId = mo.MarketOrderId
      )
      AND NOT EXISTS (
        SELECT 1 FROM MarketOrderItem x
        WHERE x.MarketOrderId = mo.MarketOrderId
          AND x.MatchStatus = 'unmatched'
      );

    -- Step 3: If no qualifying orders, return 0
    IF NOT EXISTS (SELECT 1 FROM #QualifyingOrders)
    BEGIN
        SET @NewSalesId = 0;
        RETURN;
    END

    -- Step 4: Clean up prior TempSales for this EmpId + PayeeId with SalesId=0
    DELETE FROM TempSales
    WHERE EmpId = @EmpId AND SalesId = 0 AND PayeeId = @PayeeId;

    -- Step 5: Insert into TempSales (SalesId = 0 for new order)
    INSERT INTO TempSales (EmpId, SalesId, PayeeId, LineType, ItemId, ItemUnitId,
        Unit, OrdQty, ShipQty, BillQty, UnitPrice, Notes, ChangeStatus, FactorToBase, IsTaxable)
    SELECT @EmpId, 0, @PayeeId, 'I',
        moi.ItemId, moi.ItemUnitId, iu.Unit,
        moi.Qty, moi.Qty, moi.Qty, moi.UnitPrice,
        'MKT#' + qo.ExternalOrderId,
        'I', iu.FactorToBase, 0
    FROM MarketOrderItem moi
    INNER JOIN #QualifyingOrders qo ON moi.MarketOrderId = qo.MarketOrderId
    INNER JOIN ItemUnit iu ON moi.ItemUnitId = iu.ItemUnitId;

    -- Step 6: Call Sales_Insert to create Sales header + SalesDetail + journal entries
    EXEC [Sales_Insert]
        @SalesId = 0,
        @PayeeId = @PayeeId,
        @ShipDate = @OrderDate,
        @ShipRoute = NULL,
        @Instruction = N'Marketplace',
        @StageId = 4,
        @EmpId = @EmpId,
        @NewSalesId = @NewSalesId OUTPUT,
        @DocType = 'SO';

    -- Step 7: Mark qualifying orders as imported
    IF @NewSalesId > 0
    BEGIN
        UPDATE MarketOrder
        SET ImportedToErp = 1, ErpSalesId = @NewSalesId, ImportedToErpAt = GETUTCDATE()
        WHERE MarketOrderId IN (SELECT MarketOrderId FROM #QualifyingOrders);
    END

    DROP TABLE #QualifyingOrders;
END
GO
