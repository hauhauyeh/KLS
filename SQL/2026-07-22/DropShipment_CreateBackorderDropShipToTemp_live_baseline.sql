
-- DropShipment_CreateBackorderDropShipToTemp
-- Creates a new-order TempSales cart from eligible normal backorder lines on an existing drop-ship SO.
-- No-row backorder is a normal business outcome: return GeneratedLineCount = 0 and do not touch TempSales.
-- 2026-07-22 BACKORDER-DROPSHIP-SEED: normal item lines only; Free/Out/CRCG, promo, account, system, and parent/root lines are excluded.
-- EXEC dbo.DropShipment_CreateBackorderDropShipToTemp @SalesId = 74934, @EmpId = 1;
CREATE   PROCEDURE [dbo].[DropShipment_CreateBackorderDropShipToTemp]
    @SalesId INT,
    @EmpId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @PayeeId INT;
    DECLARE @DropShipPurchaseId INT;
    DECLARE @IsDropShip BIT;
    DECLARE @VendorPayeeId INT;
    DECLARE @VendorName NVARCHAR(255);
    DECLARE @PurchaseIsDropShip BIT;
    DECLARE @PurchaseDropShipSalesId INT;
    DECLARE @CustPONumber NVARCHAR(100);
    DECLARE @FactorPO NVARCHAR(100);
    DECLARE @GeneratedLineCount INT = 0;

    DECLARE @EligibleLines TABLE
    (
        SalesDetailId INT NOT NULL,
        SourceLineId INT NULL,
        ItemId INT NOT NULL,
        ItemUnitId INT NOT NULL,
        Unit NVARCHAR(50) NULL,
        BackorderQty DECIMAL(18,2) NOT NULL,
        UnitPrice DECIMAL(18,4) NULL,
        Notes NVARCHAR(300) NULL,
        IsTaxable BIT NOT NULL,
        OrgPrice DECIMAL(18,4) NULL,
        DiscountPercent DECIMAL(18,4) NULL,
        FactorToBase DECIMAL(18,6) NOT NULL,
        MultipleToBase INT NOT NULL
    );

    SELECT
        @PayeeId = s.ShipId,
        @DropShipPurchaseId = s.DropShipPurchaseId,
        @IsDropShip = s.IsDropShip,
        @CustPONumber = s.CustPONumber
    FROM dbo.Sales s
    WHERE s.SalesId = @SalesId;

    IF @IsDropShip IS NULL
    BEGIN
        RAISERROR('Source sales order not found.', 16, 1);
        RETURN;
    END

    IF ISNULL(@IsDropShip, 0) <> 1
    BEGIN
        RAISERROR('Source sales order is not a drop-ship order.', 16, 1);
        RETURN;
    END

    IF @DropShipPurchaseId IS NULL
    BEGIN
        RAISERROR('Source drop-ship order has no linked purchase order.', 16, 1);
        RETURN;
    END

    SELECT
        @VendorPayeeId = p.PayeeId,
        @PurchaseIsDropShip = p.IsDropShip,
        @PurchaseDropShipSalesId = p.DropShipSalesId,
        @FactorPO = p.FactorPO,
        @VendorName = payee.PayeeName
    FROM dbo.Purchase p
    LEFT JOIN dbo.Payee payee ON payee.PayeeId = p.PayeeId
    WHERE p.PurchaseId = @DropShipPurchaseId;

    IF @VendorPayeeId IS NULL
    BEGIN
        RAISERROR('Linked purchase order not found.', 16, 1);
        RETURN;
    END

    IF ISNULL(@PurchaseIsDropShip, 0) <> 1
    BEGIN
        RAISERROR('Linked purchase order is not a drop-ship purchase order.', 16, 1);
        RETURN;
    END

    IF ISNULL(@PurchaseDropShipSalesId, 0) <> @SalesId
    BEGIN
        RAISERROR('Linked purchase order does not belong to the source sales order.', 16, 1);
        RETURN;
    END

    IF @PayeeId IS NULL
    BEGIN
        RAISERROR('Source sales order has no customer payee.', 16, 1);
        RETURN;
    END

    INSERT INTO @EligibleLines
    (
        SalesDetailId,
        SourceLineId,
        ItemId,
        ItemUnitId,
        Unit,
        BackorderQty,
        UnitPrice,
        Notes,
        IsTaxable,
        OrgPrice,
        DiscountPercent,
        FactorToBase,
        MultipleToBase
    )
    SELECT
        sd.SalesDetailId,
        sd.LineId,
        sd.ItemId,
        sd.ItemUnitId,
        COALESCE(sd.Unit, iu.Unit),
        CAST(ISNULL(sd.OrdQty, 0) - ISNULL(sd.ShipQty, 0) AS DECIMAL(18,2)),
        sd.UnitPrice,
        sd.Notes,
        sd.IsTaxable,
        sd.OrgPrice,
        sd.DiscountPercent,
        COALESCE(sd.FactorToBase, iu.FactorToBase),
        iu.MultipleToBase
    FROM dbo.SalesDetail sd
    INNER JOIN dbo.ItemUnit iu ON iu.ItemUnitId = sd.ItemUnitId
    WHERE sd.SalesId = @SalesId
      AND sd.LineType = 'I'
      AND sd.ItemId IS NOT NULL
      AND ISNULL(sd.IsSystemManaged, 0) = 0
      AND sd.ParentSalesDetailId IS NULL
      AND sd.RootSalesDetailId IS NULL
      AND ISNULL(sd.CartLineType, 'MAIN') = 'MAIN'
      AND ISNULL(sd.OrdQty, 0) - ISNULL(sd.ShipQty, 0) > 0;

    SELECT @GeneratedLineCount = COUNT(1)
    FROM @EligibleLines;

    IF @GeneratedLineCount = 0
    BEGIN
        SELECT
            @SalesId AS SourceSalesId,
            @PayeeId AS PayeeId,
            @VendorPayeeId AS VendorPayeeId,
            @VendorName AS VendorName,
            @CustPONumber AS CustPONumber,
            @FactorPO AS FactorPO,
            0 AS GeneratedLineCount,
            CAST('No row available for backorder' AS NVARCHAR(200)) AS [Message];
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Clear the current user's new-order cart for the source customer.
        -- Promo links must be removed before deleting TempSales rows because TempSalesPromo references TempSales.
        DELETE tsp
        FROM dbo.TempSalesPromo tsp
        WHERE EXISTS
        (
            SELECT 1
            FROM dbo.TempSales ts
            WHERE ts.EmpId = @EmpId
              AND ts.PayeeId = @PayeeId
              AND ts.SalesId = 0
              AND (ts.TempSalesId = tsp.OwnerTempSalesId OR ts.TempSalesId = tsp.PromoTempSalesId)
        );

        DELETE ts
        FROM dbo.TempSales ts
        WHERE ts.EmpId = @EmpId
          AND ts.PayeeId = @PayeeId
          AND ts.SalesId = 0;

        INSERT INTO dbo.TempSales
        (
            EmpId,
            SalesId,
            PayeeId,
            LineType,
            ItemId,
            ItemUnitId,
            Unit,
            IsFree,
            IsOut,
            IsCRCG,
            BaseOrdQty,
            OrdQty,
            ShipQty,
            BillQty,
            UnitPrice,
            ExtTotal,
            Notes,
            IsTaxable,
            OrgPrice,
            DiscountPercent,
            FactorToBase,
            ChangeStatus,
            SalesDetailId,
            IsStrike,
            ParentTempSalesId,
            RootTempSalesId,
            CartLineType,
            IsSystemManaged,
            DisplaySort
        )
        SELECT
            @EmpId,
            0,
            @PayeeId,
            'I',
            el.ItemId,
            el.ItemUnitId,
            el.Unit,
            0,
            0,
            0,
            dbo.Fn_QtyToBase(el.BackorderQty, el.MultipleToBase, el.FactorToBase),
            el.BackorderQty,
            el.BackorderQty,
            el.BackorderQty,
            el.UnitPrice,
            CAST(ROUND(el.BackorderQty * ISNULL(el.UnitPrice, 0), 2) AS DECIMAL(18,2)),
            el.Notes,
            el.IsTaxable,
            el.OrgPrice,
            el.DiscountPercent,
            el.FactorToBase,
            'I',
            NULL,
            0,
            NULL,
            NULL,
            'MAIN',
            0,
            el.SourceLineId
        FROM @EligibleLines el
        ORDER BY el.SourceLineId, el.SalesDetailId;

        SET @GeneratedLineCount = @@ROWCOUNT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH

    SELECT
        @SalesId AS SourceSalesId,
        @PayeeId AS PayeeId,
        @VendorPayeeId AS VendorPayeeId,
        @VendorName AS VendorName,
        @CustPONumber AS CustPONumber,
        @FactorPO AS FactorPO,
        @GeneratedLineCount AS GeneratedLineCount,
        CAST(NULL AS NVARCHAR(200)) AS [Message];
END

