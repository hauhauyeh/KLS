SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- DropShipment_UpdateReceiptQty
-- Line-level drop-ship customer receipt. Updates customer-received quantities on
-- the linked Sales and Purchase detail rows without changing ordered quantity.
-- EXEC dbo.DropShipment_UpdateReceiptQty @PurchaseId=13055, @EmpId=1, @ReceiptDate='2026-08-01', @ItemsJson=N'[{"PurchaseDetailId":324902,"ReceiveQty":900},{"PurchaseDetailId":324903,"ReceiveQty":1001}]';
CREATE   PROCEDURE [dbo].[DropShipment_UpdateReceiptQty]
    @PurchaseId INT,
    @EmpId INT,
    @ReceiptDate DATE,
    @ItemsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IsDropShip BIT;
    DECLARE @PurchaseStageId INT;
    DECLARE @SalesId INT;
    DECLARE @SalesStageId INT;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);
    DECLARE @SubTotal DECIMAL(18,2);
    DECLARE @TaxableTotal DECIMAL(18,2);
    DECLARE @TaxTotal DECIMAL(18,2);
    DECLARE @TaxRate DECIMAL(18,4);
    DECLARE @SalesTotal DECIMAL(18,2);
    DECLARE @PaymentApplied DECIMAL(18,2);
    DECLARE @DiscountApplied DECIMAL(18,2);
    DECLARE @AmountDue DECIMAL(18,2);
    DECLARE @BillTotal DECIMAL(18,2);
    DECLARE @FinalTotal DECIMAL(18,2);
    DECLARE @ItemLineCount INT;

    DECLARE @Receipt TABLE
    (
        RowId INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        PurchaseDetailId INT NULL,
        ReceiveQty DECIMAL(18,2) NULL
    );

    -- Section 1: validate linked drop-ship document state.
    SELECT
        @IsDropShip = p.IsDropShip,
        @PurchaseStageId = p.StageId,
        @SalesId = p.DropShipSalesId
    FROM Purchase p
    WHERE p.PurchaseId = @PurchaseId;

    IF @IsDropShip IS NULL
    BEGIN
        RAISERROR('Purchase not found.', 16, 1);
        RETURN;
    END

    IF @IsDropShip = 0
    BEGIN
        RAISERROR('This is not a drop-ship purchase.', 16, 1);
        RETURN;
    END

    -- Slice 2B: factory progress can move drop-ship PO to stage 2 before customer receipt.
    -- Receipt is still allowed only before bill conversion / later PO stages.
    IF @PurchaseStageId NOT IN (1, 2)
    BEGIN
        RAISERROR('Purchase is not in an open drop-ship PO stage. Drop-ship receipt can only be updated before Bill conversion.', 16, 1);
        RETURN;
    END

    IF @SalesId IS NULL
    BEGIN
        RAISERROR('Linked sales order not found on this drop-ship purchase.', 16, 1);
        RETURN;
    END

    SELECT
        @SalesStageId = s.StageId,
        @TaxRate = s.TaxPercent,
        @PaymentApplied = ISNULL(s.PaymentApplied, 0),
        @DiscountApplied = ISNULL(s.DiscountApplied, 0)
    FROM Sales s
    WHERE s.SalesId = @SalesId;

    IF @SalesStageId IS NULL
    BEGIN
        RAISERROR('Linked sales order not found.', 16, 1);
        RETURN;
    END

    IF @SalesStageId NOT IN (0, 1, 2)
    BEGIN
        RAISERROR('Drop-ship receipt can only be updated before customer receipt is confirmed.', 16, 1);
        RETURN;
    END

    IF @ReceiptDate IS NULL
    BEGIN
        RAISERROR('Receipt date is required.', 16, 1);
        RETURN;
    END

    -- Section 2: parse and validate the complete item-line receipt payload.
    IF @ItemsJson IS NULL OR ISJSON(@ItemsJson) <> 1
    BEGIN
        RAISERROR('Receipt items JSON is required.', 16, 1);
        RETURN;
    END

    INSERT INTO @Receipt (PurchaseDetailId, ReceiveQty)
    SELECT
        j.PurchaseDetailId,
        j.ReceiveQty
    FROM OPENJSON(@ItemsJson)
    WITH
    (
        PurchaseDetailId INT '$.PurchaseDetailId',
        ReceiveQty DECIMAL(18,2) '$.ReceiveQty'
    ) AS j;

    IF NOT EXISTS (SELECT 1 FROM @Receipt)
    BEGIN
        RAISERROR('At least one receipt line is required.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM @Receipt WHERE PurchaseDetailId IS NULL OR ReceiveQty IS NULL)
    BEGIN
        RAISERROR('Each receipt line must include PurchaseDetailId and ReceiveQty.', 16, 1);
        RETURN;
    END

    IF EXISTS
    (
        SELECT 1
        FROM @Receipt
        GROUP BY PurchaseDetailId
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR('Receipt JSON contains duplicate purchase detail lines.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM @Receipt WHERE ReceiveQty < 0)
    BEGIN
        RAISERROR('Receipt quantity cannot be negative.', 16, 1);
        RETURN;
    END

    IF EXISTS
    (
        SELECT 1
        FROM @Receipt r
        LEFT JOIN PurchaseDetail pd ON pd.PurchaseDetailId = r.PurchaseDetailId
                                  AND pd.PurchaseId = @PurchaseId
                                  AND pd.LineType = 'I'
                                  AND pd.ItemId IS NOT NULL
        WHERE pd.PurchaseDetailId IS NULL
    )
    BEGIN
        RAISERROR('One or more receipt lines do not belong to this drop-ship purchase.', 16, 1);
        RETURN;
    END

    SELECT @ItemLineCount = COUNT(*)
    FROM PurchaseDetail pd
    WHERE pd.PurchaseId = @PurchaseId
      AND pd.LineType = 'I'
      AND pd.ItemId IS NOT NULL;

    IF @ItemLineCount = 0
    BEGIN
        RAISERROR('Drop-ship purchase has no item lines to receive.', 16, 1);
        RETURN;
    END

    IF (SELECT COUNT(*) FROM @Receipt) <> @ItemLineCount
    BEGIN
        RAISERROR('Receipt JSON must include every item line on the drop-ship purchase. Use zero for lines not received.', 16, 1);
        RETURN;
    END

    -- Section 3: prove PurchaseDetail-to-SalesDetail mapping before changing quantities.
    -- The drop-ship PO stores no direct SalesDetailId. It is generated item-only
    -- from SalesDetail with LineId and ItemId preserved, so that pair must be unique.
    IF EXISTS
    (
        SELECT 1
        FROM SalesDetail sd
        WHERE sd.SalesId = @SalesId
          AND sd.LineType = 'I'
          AND sd.ItemId IS NOT NULL
        GROUP BY sd.LineId, sd.ItemId
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR('Linked sales order has ambiguous item-line mapping.', 16, 1);
        RETURN;
    END

    IF EXISTS
    (
        SELECT 1
        FROM PurchaseDetail pd
        WHERE pd.PurchaseId = @PurchaseId
          AND pd.LineType = 'I'
          AND pd.ItemId IS NOT NULL
        GROUP BY pd.LineId, pd.ItemId
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR('Drop-ship purchase has ambiguous item-line mapping.', 16, 1);
        RETURN;
    END

    IF EXISTS
    (
        SELECT 1
        FROM @Receipt r
        INNER JOIN PurchaseDetail pd ON pd.PurchaseDetailId = r.PurchaseDetailId
        OUTER APPLY
        (
            SELECT COUNT(*) AS MatchCount
            FROM SalesDetail sd
            WHERE sd.SalesId = @SalesId
              AND sd.LineType = 'I'
              AND sd.LineId = pd.LineId
              AND sd.ItemId = pd.ItemId
        ) m
        WHERE ISNULL(m.MatchCount, 0) <> 1
    )
    BEGIN
        RAISERROR('One or more receipt lines cannot be matched to the linked sales order.', 16, 1);
        RETURN;
    END

    SET @LockResource =
        'DropShip_UpdateShipQty_'
        + CONVERT(NVARCHAR(20), @PurchaseId);

    -- Section 4: update receipt quantities under the same lock as the legacy full-receipt path.
    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
        BEGIN
            RAISERROR('This drop-ship receipt is already being processed.', 16, 1);
        END

        -- Section 5: update detail quantities without changing ordered quantity.
        UPDATE pd
        SET
            -- Slice 2B: ShipQty/BillQty were factory-confirmed values and were previously unchanged here.
            -- pd.ShipQty = r.ReceiveQty,
            -- pd.BillQty = r.ReceiveQty,
            -- 2026-07-28: default purchase ship/bill qty from receipt only when both were blank.
            pd.ShipQty =
                CASE
                    WHEN pd.ShipQty IS NULL AND pd.BillQty IS NULL THEN r.ReceiveQty
                    ELSE pd.ShipQty
                END,
            pd.BillQty =
                CASE
                    WHEN pd.ShipQty IS NULL AND pd.BillQty IS NULL THEN r.ReceiveQty
                    ELSE pd.BillQty
                END,
            pd.ReceiveQty = r.ReceiveQty,
            pd.FinalQty = r.ReceiveQty
        FROM PurchaseDetail pd
        INNER JOIN @Receipt r ON r.PurchaseDetailId = pd.PurchaseDetailId
        WHERE pd.PurchaseId = @PurchaseId;

        IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Receipt)
        BEGIN
            RAISERROR('Not all purchase receipt lines were updated.', 16, 1);
        END

        UPDATE pd
        SET
            pd.BaseReceiveQty = dbo.Fn_QtyToBase(pd.ReceiveQty, iu.MultipleToBase, iu.FactorToBase),
            pd.BaseFinalQty = dbo.Fn_QtyToBase(pd.FinalQty, iu.MultipleToBase, iu.FactorToBase)
        FROM PurchaseDetail pd
        INNER JOIN @Receipt r ON r.PurchaseDetailId = pd.PurchaseDetailId
        INNER JOIN ItemUnit iu ON iu.ItemUnitId = pd.ItemUnitId
        WHERE pd.PurchaseId = @PurchaseId;

        UPDATE sd
        SET
            sd.ShipQty = r.ReceiveQty,
            -- Slice 2B: SalesDetail has no IsFree column; preserve Free from its existing qty pattern.
            sd.BillQty =
                CASE
                    WHEN ISNULL(sd.BillQty, 0) = 0 AND ISNULL(sd.ShipQty, 0) <> 0 THEN 0
                    ELSE r.ReceiveQty
                END,
            sd.ExtTotal =
                ROUND(
                    ISNULL(
                        CASE
                            WHEN ISNULL(sd.BillQty, 0) = 0 AND ISNULL(sd.ShipQty, 0) <> 0 THEN 0
                            ELSE r.ReceiveQty
                        END,
                        0
                    ) * ISNULL(sd.UnitPrice, 0),
                    2
                )
        FROM SalesDetail sd
        INNER JOIN PurchaseDetail pd ON pd.PurchaseId = @PurchaseId
                                   AND pd.LineId = sd.LineId
                                   AND pd.ItemId = sd.ItemId
        INNER JOIN @Receipt r ON r.PurchaseDetailId = pd.PurchaseDetailId
        WHERE sd.SalesId = @SalesId
          AND sd.LineType = 'I'
          AND pd.LineType = 'I';

        IF @@ROWCOUNT <> (SELECT COUNT(*) FROM @Receipt)
        BEGIN
            RAISERROR('Not all linked sales receipt lines were updated.', 16, 1);
        END

        UPDATE sd
        SET
            sd.BaseShipQty = dbo.Fn_QtyToBase(sd.ShipQty, iu.MultipleToBase, iu.FactorToBase),
            sd.BaseBillQty = dbo.Fn_QtyToBase(sd.BillQty, iu.MultipleToBase, iu.FactorToBase)
        FROM SalesDetail sd
        INNER JOIN PurchaseDetail pd ON pd.PurchaseId = @PurchaseId
                                   AND pd.LineId = sd.LineId
                                   AND pd.ItemId = sd.ItemId
        INNER JOIN @Receipt r ON r.PurchaseDetailId = pd.PurchaseDetailId
        INNER JOIN ItemUnit iu ON iu.ItemUnitId = sd.ItemUnitId
        WHERE sd.SalesId = @SalesId
          AND sd.LineType = 'I'
          AND pd.LineType = 'I';

        -- Section 6: refresh core header totals from the adjusted detail quantities.
        -- Sales_CalcTotal and Purchase_CalcTotalAndPercent no longer own these core totals.
        SELECT @SubTotal = ISNULL(SUM(ROUND(ISNULL(BillQty, 0) * ISNULL(UnitPrice, 0), 2)), 0)
        FROM SalesDetail
        WHERE SalesId = @SalesId;

        SELECT @TaxableTotal = ISNULL(SUM(ROUND(ISNULL(BillQty, 0) * ISNULL(UnitPrice, 0), 2)), 0)
        FROM SalesDetail
        WHERE SalesId = @SalesId
          AND IsTaxable = 1;

        SET @TaxTotal = ROUND(@TaxableTotal * ISNULL(@TaxRate, 0), 2);
        SET @SalesTotal = @SubTotal + @TaxTotal;
        SET @AmountDue = @SalesTotal - (ISNULL(@PaymentApplied, 0) + ISNULL(@DiscountApplied, 0));

        SELECT
            @BillTotal = ISNULL(SUM(ROUND(ISNULL(BillQty, 0) * ISNULL(BillPrice, 0), 2)), 0),
            @FinalTotal = ISNULL(SUM(ROUND(ISNULL(FinalQty, 0) * ISNULL(FinalPrice, 0), 2)), 0)
        FROM PurchaseDetail
        WHERE PurchaseId = @PurchaseId;

        UPDATE Sales
        SET
            StageId = 3,
            ShipDate = @ReceiptDate,
            SubTotal = @SubTotal,
            TaxableTotal = @TaxableTotal,
            TaxTotal = @TaxTotal,
            SalesTotal = @SalesTotal,
            AmountDue = @AmountDue,
            UpdatedAt = GETUTCDATE()
        WHERE SalesId = @SalesId;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Linked sales order was not updated for this drop-ship receipt.', 16, 1);
        END

        UPDATE Purchase
        SET
            ArrivalDate = @ReceiptDate,
            VendorTotal = @BillTotal,
            PurchaseTotal = @FinalTotal,
            UpdatedAt = GETUTCDATE()
        WHERE PurchaseId = @PurchaseId;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Drop-ship purchase header was not updated for this receipt.', 16, 1);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    -- Section 7: no post-follow-up helpers run here. Sales_CalcTotal would run
    -- final FIFO allocation after Stage 3, and Purchase_CalcTotalAndPercent would
    -- stage-advance the PO and block ConvertPOToBill.

    SELECT
        @SalesId AS SalesId,
        @PurchaseId AS PurchaseId,
        (SELECT COUNT(*) FROM @Receipt) AS ReceivedLineCount,
        CAST(CASE WHEN EXISTS
        (
            SELECT 1
            FROM SalesDetail sd
            WHERE sd.SalesId = @SalesId
              AND sd.LineType = 'I'
              AND ISNULL(sd.OrdQty, 0) - ISNULL(sd.ShipQty, 0) > 0
        ) THEN 1 ELSE 0 END AS BIT) AS HasBackorder;
END


GO
