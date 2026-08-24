
-- DropShipment_PrecheckBackorderDropShipCheckout
-- 2026-07-22 BACKORDER-DROPSHIP-CHECKOUT-PRECHECK: read-only guard for forced backorder drop-ship checkout.
-- 2026-07-22 BACKORDER-DROPSHIP-DUPLICATE-GUARD: source SO can post only one backorder drop-ship.
-- 2026-08-09 BACKORDER-DROPSHIP-ROOT-CHAIN: source SO can post only when it is the latest row in its root chain.
-- EXEC dbo.DropShipment_PrecheckBackorderDropShipCheckout @SalesId = 0, @SourceSalesId = 74934, @PayeeId = 301383, @VendorPayeeId = 200393, @EmpId = 1;
CREATE   PROCEDURE [dbo].[DropShipment_PrecheckBackorderDropShipCheckout]
    @SalesId INT,
    @SourceSalesId INT,
    @PayeeId INT,
    @VendorPayeeId INT,
    @EmpId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SourcePayeeId INT;
    DECLARE @DropShipPurchaseId INT;
    DECLARE @SourceIsDropShip BIT;
    DECLARE @PurchaseVendorPayeeId INT;
    DECLARE @PurchaseIsDropShip BIT;
    DECLARE @PurchaseDropShipSalesId INT;
    DECLARE @SourceSalesNumber INT;
    DECLARE @RootSalesNumber INT;
    DECLARE @SourceCreatedAt DATETIME;

    DECLARE @TempRows TABLE
    (
        SourceLineId INT NOT NULL,
        ItemId INT NOT NULL,
        ItemUnitId INT NOT NULL,
        BackorderQty DECIMAL(18,2) NOT NULL,
        LineCount INT NOT NULL
    );

    DECLARE @EligibleRows TABLE
    (
        SourceLineId INT NOT NULL,
        ItemId INT NOT NULL,
        ItemUnitId INT NOT NULL,
        BackorderQty DECIMAL(18,2) NOT NULL,
        LineCount INT NOT NULL
    );

    IF @SalesId <> 0
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Backorder drop-ship checkout must create a new sales order.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF ISNULL(@SourceSalesId, 0) <= 0
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Source sales order is required.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    SELECT
        @SourcePayeeId = s.ShipId,
        @SourceSalesNumber = s.SalesNumber,
        @RootSalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber),
        @SourceCreatedAt = s.CreatedAt,
        @DropShipPurchaseId = s.DropShipPurchaseId,
        @SourceIsDropShip = s.IsDropShip
    FROM dbo.Sales s
    WHERE s.SalesId = @SourceSalesId;

    IF @SourceIsDropShip IS NULL
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Source sales order not found.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF @SourceIsDropShip = 0
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Source sales order is not a drop-ship order.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF @DropShipPurchaseId IS NULL
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Source sales order does not have a linked drop-ship purchase order.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    SELECT
        @PurchaseVendorPayeeId = p.PayeeId,
        @PurchaseIsDropShip = p.IsDropShip,
        @PurchaseDropShipSalesId = p.DropShipSalesId
    FROM dbo.Purchase p
    WHERE p.PurchaseId = @DropShipPurchaseId;

    IF @PurchaseVendorPayeeId IS NULL
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Linked purchase order not found.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF ISNULL(@PurchaseIsDropShip, 0) = 0
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Linked purchase order is not a drop-ship purchase order.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF ISNULL(@PurchaseDropShipSalesId, 0) <> @SourceSalesId
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Linked purchase order does not belong to the source sales order.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF ISNULL(@SourcePayeeId, 0) <> @PayeeId
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Backorder customer does not match the source sales order.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF ISNULL(@PurchaseVendorPayeeId, 0) <> @VendorPayeeId
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Backorder vendor does not match the linked purchase order.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Sales chainLater
        WHERE (chainLater.SalesNumber = @RootSalesNumber
            OR chainLater.ParentSalesNumber = @RootSalesNumber)
          AND chainLater.SalesNumber <> @SourceSalesNumber
          AND chainLater.IsDropShip = 1
          AND chainLater.DocType = 'SO'
          AND
          (
              CASE WHEN chainLater.SalesNumber = @RootSalesNumber THEN 0 ELSE 1 END
                > CASE WHEN @SourceSalesNumber = @RootSalesNumber THEN 0 ELSE 1 END
              OR
              (
                  CASE WHEN chainLater.SalesNumber = @RootSalesNumber THEN 0 ELSE 1 END
                    = CASE WHEN @SourceSalesNumber = @RootSalesNumber THEN 0 ELSE 1 END
                  AND ISNULL(chainLater.CreatedAt, '19000101') > ISNULL(@SourceCreatedAt, '19000101')
              )
              OR
              (
                  CASE WHEN chainLater.SalesNumber = @RootSalesNumber THEN 0 ELSE 1 END
                    = CASE WHEN @SourceSalesNumber = @RootSalesNumber THEN 0 ELSE 1 END
                  AND ISNULL(chainLater.CreatedAt, '19000101') = ISNULL(@SourceCreatedAt, '19000101')
                  AND chainLater.SalesNumber > @SourceSalesNumber
              )
          )
    )
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Backorder drop-ship already exists after this source order.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.TempSales ts
        WHERE ts.EmpId = @EmpId
          AND ts.PayeeId = @PayeeId
          AND ts.SalesId = 0
          AND ts.IsStrike = 0
    )
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('No rows found for this checkout group.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF EXISTS
    (
        SELECT 1
        FROM dbo.TempSales ts
        WHERE ts.EmpId = @EmpId
          AND ts.PayeeId = @PayeeId
          AND ts.SalesId = 0
          AND ts.IsStrike = 0
          AND (ts.IsFree = 1 OR ts.IsOut = 1 OR ts.IsCRCG = 1)
    )
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Backorder drop-ship cannot include Free, Out, or CRCG lines.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF EXISTS
    (
        SELECT 1
        FROM dbo.TempSales ts
        WHERE ts.EmpId = @EmpId
          AND ts.PayeeId = @PayeeId
          AND ts.SalesId = 0
          AND ts.IsStrike = 0
          AND
          (
              ts.LineType <> 'I'
              OR ts.ItemId IS NULL
              OR ts.AccountId IS NOT NULL
              OR ts.ItemUnitId IS NULL
              OR ts.IsSystemManaged = 1
              OR ts.ParentTempSalesId IS NOT NULL
              OR ts.RootTempSalesId IS NOT NULL
              OR ISNULL(ts.CartLineType, '') <> 'MAIN'
              OR ts.DisplaySort IS NULL
              OR ISNULL(ts.OrdQty, 0) <= 0
              OR ISNULL(ts.OrdQty, 0) <> ISNULL(ts.ShipQty, 0)
              OR ISNULL(ts.OrdQty, 0) <> ISNULL(ts.BillQty, 0)
          )
    )
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Backorder drop-ship cart contains rows that are not normal item backorder lines.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF EXISTS
    (
        SELECT 1
        FROM dbo.TempSalesPromo tsp
        WHERE EXISTS
        (
            SELECT 1
            FROM dbo.TempSales ts
            WHERE ts.EmpId = @EmpId
              AND ts.PayeeId = @PayeeId
              AND ts.SalesId = 0
              AND ts.IsStrike = 0
              AND (ts.TempSalesId = tsp.OwnerTempSalesId OR ts.TempSalesId = tsp.PromoTempSalesId)
        )
    )
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Backorder drop-ship cannot include promotional lines.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    INSERT INTO @TempRows
    (
        SourceLineId,
        ItemId,
        ItemUnitId,
        BackorderQty,
        LineCount
    )
    SELECT
        ts.DisplaySort,
        ts.ItemId,
        ts.ItemUnitId,
        CAST(ts.OrdQty AS DECIMAL(18,2)),
        COUNT(1)
    FROM dbo.TempSales ts
    WHERE ts.EmpId = @EmpId
      AND ts.PayeeId = @PayeeId
      AND ts.SalesId = 0
      AND ts.IsStrike = 0
    GROUP BY
        ts.DisplaySort,
        ts.ItemId,
        ts.ItemUnitId,
        CAST(ts.OrdQty AS DECIMAL(18,2));

    INSERT INTO @EligibleRows
    (
        SourceLineId,
        ItemId,
        ItemUnitId,
        BackorderQty,
        LineCount
    )
    SELECT
        sd.LineId,
        sd.ItemId,
        sd.ItemUnitId,
        CAST(ISNULL(sd.OrdQty, 0) - ISNULL(sd.ShipQty, 0) AS DECIMAL(18,2)),
        COUNT(1)
    FROM dbo.SalesDetail sd
    WHERE sd.SalesId = @SourceSalesId
      AND sd.LineId IS NOT NULL
      AND sd.LineType = 'I'
      AND sd.ItemId IS NOT NULL
      AND sd.AccountId IS NULL
      AND sd.ItemUnitId IS NOT NULL
      AND ISNULL(sd.IsSystemManaged, 0) = 0
      AND sd.ParentSalesDetailId IS NULL
      AND sd.RootSalesDetailId IS NULL
      AND ISNULL(sd.CartLineType, '') = 'MAIN'
      AND ISNULL(sd.OrdQty, 0) - ISNULL(sd.ShipQty, 0) > 0
    GROUP BY
        sd.LineId,
        sd.ItemId,
        sd.ItemUnitId,
        CAST(ISNULL(sd.OrdQty, 0) - ISNULL(sd.ShipQty, 0) AS DECIMAL(18,2));

    IF NOT EXISTS (SELECT 1 FROM @EligibleRows)
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('No row available for backorder.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF (SELECT COUNT(1) FROM @TempRows) <> (SELECT COUNT(1) FROM @EligibleRows)
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Backorder drop-ship cart no longer matches the source backorder quantities.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    IF EXISTS
    (
        SELECT SourceLineId, ItemId, ItemUnitId, BackorderQty, LineCount FROM @TempRows
        EXCEPT
        SELECT SourceLineId, ItemId, ItemUnitId, BackorderQty, LineCount FROM @EligibleRows
    )
    OR EXISTS
    (
        SELECT SourceLineId, ItemId, ItemUnitId, BackorderQty, LineCount FROM @EligibleRows
        EXCEPT
        SELECT SourceLineId, ItemId, ItemUnitId, BackorderQty, LineCount FROM @TempRows
    )
    BEGIN
        SELECT CAST(0 AS BIT) AS CanPost, CAST('Backorder drop-ship cart no longer matches the source backorder quantities.' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    SELECT CAST(1 AS BIT) AS CanPost, CAST(NULL AS NVARCHAR(200)) AS [Message];
END
