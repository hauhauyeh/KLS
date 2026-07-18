-- DropShipment_GeneratePOFromSales  (NEW 2026-07-13, Slice 1 of plan-dropship-2-checkout-two-step.md)
-- Convert an existing NORMAL sales order (StageId=0) into a drop-ship order: generate its linked vendor PO
-- from the committed SalesDetail ITEM lines (LineType='I'; account lines stay on the SO), stamp the required
-- ETA Date as Purchase.ArrivalDate + Sales.ShipDate, then flag the SO drop-ship + set the bidirectional link.
-- Step 2 of the two-step workflow (Step 1 = normal checkout).
-- No journal entries (PO is StageId=1).
-- v1 (direct-insert): source SO is already committed, so we insert SalesDetail -> PurchaseDetail DIRECTLY -
-- no TempPurchase, no staging trigger dependency, no shared-staging app lock. PO LineId is fresh contiguous
-- (ROW_NUMBER over SalesDetail line order) since account lines are excluded. Column mapping matches the
-- purchase-side of DropShipment_InsertSalesAndPO.
-- EXEC dbo.DropShipment_GeneratePOFromSales @SalesId=123, @VendorPayeeId=456, @EmpId=1, @ArrivalDate='2026-07-20', @NewPurchaseId=0;
CREATE   PROCEDURE [dbo].[DropShipment_GeneratePOFromSales]
    @SalesId INT,
    @VendorPayeeId INT,
    @EmpId INT,
    @ArrivalDate DATE = NULL,
    @NewPurchaseId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @PurchaseId INT;
    DECLARE @PurchaseNumber INT;
    DECLARE @VendorTermId INT;
    DECLARE @BillTotal DECIMAL(18,2);
    DECLARE @FinalTotal DECIMAL(18,2);
    DECLARE @SalesStageId INT;
    DECLARE @SalesIsLocked BIT;
    DECLARE @SalesIsDropShip BIT;
    DECLARE @SalesDropShipPurchaseId INT;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);

    -- ============================================================
    -- Validate the sales order (all pre-transaction; RAISERROR + RETURN)
    -- ============================================================
    SELECT
        @SalesStageId = StageId,
        @SalesIsLocked = ISNULL(IsLocked, 0),
        @SalesIsDropShip = ISNULL(IsDropShip, 0),
        @SalesDropShipPurchaseId = DropShipPurchaseId
    FROM Sales WHERE SalesId = @SalesId;

    IF @SalesStageId IS NULL
    BEGIN
        RAISERROR('Sales order not found.', 16, 1);
        RETURN;
    END

    -- MVP: only an Order-stage (StageId=0) SO may be converted.
    IF @SalesStageId <> 0
    BEGIN
        RAISERROR('Only an Order-stage sales order can be converted to a drop-ship PO.', 16, 1);
        RETURN;
    END

    IF @SalesIsLocked = 1
    BEGIN
        RAISERROR('Sales order is locked.', 16, 1);
        RETURN;
    END

    IF @SalesIsDropShip = 1 OR @SalesDropShipPurchaseId IS NOT NULL
    BEGIN
        RAISERROR('This sales order is already a drop-ship order.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Purchase WHERE DropShipSalesId = @SalesId)
    BEGIN
        RAISERROR('A drop-ship PO already exists for this sales order.', 16, 1);
        RETURN;
    END

    -- Validate vendor
    SELECT @VendorTermId = TermId FROM Payee WHERE PayeeId = @VendorPayeeId;
    IF @VendorTermId IS NULL
    BEGIN
        RAISERROR('Vendor payee not found.', 16, 1);
        RETURN;
    END
    IF NOT EXISTS (SELECT 1 FROM Vendor WHERE PayeeId = @VendorPayeeId)
    BEGIN
        RAISERROR('Selected payee is not a vendor.', 16, 1);
        RETURN;
    END

    -- Must have >=1 item line to source from a vendor (account lines are excluded from the PO).
    IF NOT EXISTS (SELECT 1 FROM SalesDetail WHERE SalesId = @SalesId AND LineType = 'I')
    BEGIN
        RAISERROR('This order has no item lines to source from a vendor.', 16, 1);
        RETURN;
    END

    -- Convert-existing-SO requires a business ETA. This maps to Purchase.ArrivalDate and keeps Sales.ShipDate in sync.
    IF @ArrivalDate IS NULL
    BEGIN
        RAISERROR('ETA Date is required.', 16, 1);
        RETURN;
    END

    SET @LockResource = 'DropShip_GeneratePOFromSales_' + CONVERT(NVARCHAR(20), @SalesId);

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
            RAISERROR('This drop-ship conversion is already being processed.', 16, 1);

        -- Re-check the FULL convertible state under the lock. Normal edit/delete/advance paths don't take this
        -- app lock, so the SO could have changed since the pre-transaction validation. Closes the stale-state race.
        IF NOT EXISTS (
            SELECT 1 FROM Sales
            WHERE SalesId = @SalesId
              AND StageId = 0
              AND ISNULL(IsLocked, 0) = 0
              AND ISNULL(IsDropShip, 0) = 0
              AND DropShipPurchaseId IS NULL
        )
            RAISERROR('Sales order is no longer eligible for drop-ship conversion.', 16, 1);

        IF EXISTS (SELECT 1 FROM Purchase WHERE DropShipSalesId = @SalesId)
            RAISERROR('A drop-ship PO already exists for this sales order.', 16, 1);

        -- ============================================================
        -- Create the drop-ship PO header (StageId=1) - header first so @PurchaseId exists for the direct detail insert
        -- ============================================================
        SET @PurchaseNumber = NEXT VALUE FOR dbo.Seq_PurchaseNumber;

        INSERT INTO [dbo].[Purchase]
            ([PurchaseNumber],[StageId],[PayeeId],[PurchaseDate],[EnterDate],[ArrivalDate],[TermId]
            ,[VendorTotal],[PurchaseTotal],[AmountDue],[PaymentApplied],[DiscountApplied]
            ,[IsLocked],[IsStartFromPO],[IsDropShip],[DropShipSalesId],[CreatedAt])
        VALUES
            (@PurchaseNumber, 1, @VendorPayeeId, CAST(GETDATE() AS DATE), GETDATE(), @ArrivalDate, @VendorTermId
            ,0, 0, 0, 0, 0
            ,0, 1, 1, @SalesId, GETUTCDATE());

        SET @PurchaseId = SCOPE_IDENTITY();

        -- ============================================================
        -- Insert PurchaseDetail DIRECTLY from committed SalesDetail ITEM lines (no TempPurchase).
        -- LineId is fresh contiguous via ROW_NUMBER (account lines are excluded). Same mapping as the
        -- purchase-side of DropShipment_InsertSalesAndPO: BillPrice/FinalPrice = ItemUnit.RecentCost,
        -- OrdQty0/OrdQty1 = OrdQty, IsFree/IsOut/IsCRCG from BillQty/ShipQty, ship/bill/receive/final = NULL.
        -- ============================================================
        INSERT INTO [dbo].[PurchaseDetail]
            ([PurchaseId],[LineId],[LineType],[ItemId],[AccountId],[ItemUnitId],[Unit],[Notes]
            ,[IsFree],[IsOut],[IsCRCG],[OrdQty0],[ShipQty],[BillQty],[OrdQty1],[ReceiveQty],[FinalQty]
            ,[BillPrice],[BillExtTotal],[FinalPrice],[ImportCommission],[FinalExtTotal],[FactorToBase],[ExpiryDate])
        SELECT
            @PurchaseId
            ,ROW_NUMBER() OVER (ORDER BY sd.LineId)
            ,sd.[LineType]
            ,sd.[ItemId]
            ,sd.[AccountId]
            ,sd.[ItemUnitId]
            ,sd.[Unit]
            ,sd.[Notes]
            ,CASE WHEN (sd.BillQty = 0 AND sd.ShipQty != 0) THEN 1 ELSE 0 END
            ,CASE WHEN (sd.BillQty = 0 AND sd.ShipQty = 0) THEN 1 ELSE 0 END
            ,CASE WHEN (sd.BillQty != 0 AND sd.ShipQty = 0) THEN 1 ELSE 0 END
            ,sd.[OrdQty]
            ,NULL
            ,NULL
            ,sd.[OrdQty]
            ,NULL
            ,NULL
            ,ISNULL(i.RecentCost, 0)
            ,NULL
            ,ISNULL(i.RecentCost, 0)
            ,NULL
            ,NULL
            ,sd.[FactorToBase]
            ,NULL
        FROM SalesDetail sd
        LEFT JOIN ItemUnit i ON i.ItemUnitId = sd.ItemUnitId
        WHERE sd.SalesId = @SalesId
          AND sd.LineType = 'I'   -- item lines only; account lines stay on the SO
        ORDER BY sd.LineId;

        -- Fail fast: a converted SO must produce >=1 PO detail line.
        IF @@ROWCOUNT = 0
            RAISERROR('No PO detail lines were created from the sales order.', 16, 1);

        -- Purchase totals
        SELECT
            @BillTotal  = ISNULL(SUM(ROUND(BillQty  * BillPrice,  2)), 0),
            @FinalTotal = ISNULL(SUM(ROUND(FinalQty * FinalPrice, 2)), 0)
        FROM PurchaseDetail WHERE PurchaseId = @PurchaseId;

        UPDATE Purchase SET VendorTotal = @BillTotal, PurchaseTotal = @FinalTotal
        WHERE PurchaseId = @PurchaseId;

        -- Required write step: totals must have applied to the just-created PO.
        IF @@ROWCOUNT = 0
            RAISERROR('Failed to update generated drop-ship PO totals.', 16, 1);

        -- ============================================================
        -- Flag + link the sales order as drop-ship (bidirectional)
        -- ============================================================
        UPDATE Sales SET
            IsDropShip = 1,
            DropShipPurchaseId = @PurchaseId,
            ShipDate = @ArrivalDate
        WHERE SalesId = @SalesId;

        -- Required write step: the SO link must have applied to exactly the one row.
        IF @@ROWCOUNT = 0
            RAISERROR('Failed to link sales order to generated drop-ship PO.', 16, 1);

        SET @NewPurchaseId = @PurchaseId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    -- Post-commit: SO totals unchanged by conversion; recalc the new PO only.
    EXEC [Purchase_CalcTotalAndPercent] @PurchaseId, @FinalTotal OUTPUT
END
