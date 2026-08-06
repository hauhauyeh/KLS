SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- DS-STAGE3-PRICE-NOTE 2026-08-06
-- Sales-side-only drop-ship stage-3 correction. Allows existing detail lines to
-- change UnitPrice and Notes only. Does not update linked Purchase/PurchaseDetail.
-- New procedure; no live baseline exists as of 2026-08-06.
-- EXEC: DECLARE @NeedsReprint bit; EXEC dbo.Sales_DropShipStage3PriceNoteUpdate @SalesId=0,@EmpId=1,@NeedsReprint=@NeedsReprint OUTPUT; SELECT @NeedsReprint AS NeedsReprint;
CREATE OR ALTER PROCEDURE [dbo].[Sales_DropShipStage3PriceNoteUpdate]
    @SalesId INT,
    @EmpId INT,
    @NeedsReprint BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NeedsReprint = 0;

    DECLARE @TxId BIGINT;
    DECLARE @SalesNumber INT;
    DECLARE @DocType CHAR(2);
    DECLARE @JournalDocType NVARCHAR(100);
    DECLARE @ShipDate DATE;
    DECLARE @StageId INT;
    DECLARE @IsDropShip BIT;
    DECLARE @IsLocked BIT;
    DECLARE @PayeeId INT;
    DECLARE @DropShipPurchaseId INT;
    DECLARE @TaxPercent DECIMAL(18,4);
    DECLARE @PaymentApplied DECIMAL(18,2);
    DECLARE @DiscountApplied DECIMAL(18,2);
    DECLARE @PurchaseLocked BIT;
    DECLARE @PurchasePaymentApplied DECIMAL(18,2);
    DECLARE @PurchaseDiscountApplied DECIMAL(18,2);
    DECLARE @SubTotal DECIMAL(18,2);
    DECLARE @TaxableTotal DECIMAL(18,2);
    DECLARE @TaxTotal DECIMAL(18,2);
    DECLARE @SalesTotal DECIMAL(18,2);
    DECLARE @CrDeAmount DECIMAL(18,2);
    DECLARE @AccountId INT;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);
    DECLARE @TotalCount INT;

    DECLARE @AcctTable TABLE
    (
        Id INT IDENTITY(1,1),
        AccountCode NVARCHAR(50),
        AccountId INT
    );

    INSERT INTO @AcctTable(AccountCode) VALUES('@AR');
    INSERT INTO @AcctTable(AccountCode) VALUES('@FSTP');
    INSERT INTO @AcctTable(AccountCode) VALUES('@ICREDIT');
    INSERT INTO @AcctTable(AccountCode) VALUES('@ISALE');
    INSERT INTO @AcctTable(AccountCode) VALUES('@COGS');
    INSERT INTO @AcctTable(AccountCode) VALUES('@INV');

    UPDATE t
    SET t.AccountId = a.AccountId
    FROM @AcctTable t
    INNER JOIN Account a ON a.AccountCode = t.AccountCode;

    SELECT
        @SalesNumber = s.SalesNumber,
        @DocType = s.DocType,
        @ShipDate = s.ShipDate,
        @StageId = s.StageId,
        @IsDropShip = s.IsDropShip,
        @IsLocked = s.IsLocked,
        @PayeeId = s.ShipId,
        @DropShipPurchaseId = s.DropShipPurchaseId,
        @TaxPercent = s.TaxPercent,
        @PaymentApplied = ISNULL(s.PaymentApplied, 0),
        @DiscountApplied = ISNULL(s.DiscountApplied, 0)
    FROM Sales s
    WHERE s.SalesId = @SalesId;

    IF @SalesNumber IS NULL
    BEGIN
        RAISERROR('Sales record not found.', 16, 1);
        RETURN;
    END

    IF ISNULL(@IsDropShip, 0) = 0
    BEGIN
        RAISERROR('This is not a drop-ship sales order.', 16, 1);
        RETURN;
    END

    IF ISNULL(@StageId, -1) <> 3
    BEGIN
        RAISERROR('Drop-ship price/comment correction is allowed only while Sales is in transit stage.', 16, 1);
        RETURN;
    END

    IF ISNULL(@IsLocked, 0) = 1 OR @PaymentApplied <> 0 OR @DiscountApplied <> 0
    BEGIN
        RAISERROR('This sales order has payment or lock activity and cannot be corrected here.', 16, 1);
        RETURN;
    END

    IF @DropShipPurchaseId IS NULL
    BEGIN
        RAISERROR('Linked drop-ship purchase was not found on this sales order.', 16, 1);
        RETURN;
    END

    SELECT
        @PurchaseLocked = p.IsLocked,
        @PurchasePaymentApplied = ISNULL(p.PaymentApplied, 0),
        @PurchaseDiscountApplied = ISNULL(p.DiscountApplied, 0)
    FROM Purchase p
    WHERE p.PurchaseId = @DropShipPurchaseId
      AND p.IsDropShip = 1
      AND p.DropShipSalesId = @SalesId;

    IF @PurchaseLocked IS NULL
    BEGIN
        RAISERROR('Linked drop-ship purchase was not found.', 16, 1);
        RETURN;
    END

    IF ISNULL(@PurchaseLocked, 0) = 1 OR @PurchasePaymentApplied <> 0 OR @PurchaseDiscountApplied <> 0
    BEGIN
        RAISERROR('Linked drop-ship purchase has payment or lock activity and cannot be corrected here.', 16, 1);
        RETURN;
    END

    SET @JournalDocType = CASE
        WHEN @DocType = 'CM' THEN 'Sales Credit Memo'
        WHEN @DocType = 'DM' THEN 'Sales Debit Memo'
        ELSE 'Sales'
    END;

    SELECT @TxId = TxId
    FROM TransactionJournal
    WHERE SourceDocNumber = @SalesNumber
      AND SourceDocType = @JournalDocType;

    IF @TxId IS NULL
    BEGIN
        RAISERROR('TransactionJournal not found for this sales order.', 16, 1);
        RETURN;
    END

    DECLARE @TempLines TABLE
    (
        TempSalesId INT NOT NULL,
        SalesDetailId INT NULL,
        LineId INT NULL,
        LineType NVARCHAR(1) NOT NULL,
        ItemId INT NULL,
        AccountId INT NULL,
        ItemUnitId INT NULL,
        Unit NVARCHAR(50) NULL,
        OrdQty DECIMAL(18,2) NULL,
        ShipQty DECIMAL(18,2) NULL,
        BillQty DECIMAL(18,2) NULL,
        UnitPrice DECIMAL(18,4) NULL,
        ExtTotal DECIMAL(18,2) NULL,
        Notes NVARCHAR(300) NULL,
        IsTaxable BIT NOT NULL,
        OrgPrice DECIMAL(18,4) NULL,
        DiscountPercent DECIMAL(18,4) NULL,
        FactorToBase DECIMAL(18,6) NULL,
        ChangeStatus NVARCHAR(1) NULL,
        CartLineType NVARCHAR(30) NOT NULL,
        IsSystemManaged BIT NOT NULL,
        DisplaySort INT NULL
    );

    INSERT INTO @TempLines
        (TempSalesId, SalesDetailId, LineId, LineType, ItemId, AccountId, ItemUnitId, Unit,
         OrdQty, ShipQty, BillQty, UnitPrice, ExtTotal, Notes, IsTaxable, OrgPrice,
         DiscountPercent, FactorToBase, ChangeStatus, CartLineType, IsSystemManaged, DisplaySort)
    SELECT
        TempSalesId, SalesDetailId, LineId, LineType, ItemId, AccountId, ItemUnitId, Unit,
        OrdQty, ShipQty, BillQty, UnitPrice, ExtTotal, Notes, IsTaxable, OrgPrice,
        DiscountPercent, FactorToBase, ChangeStatus, CartLineType, IsSystemManaged, DisplaySort
    FROM TempSales
    WHERE EmpId = @EmpId
      AND PayeeId = @PayeeId
      AND SalesId = @SalesId;

    IF NOT EXISTS (SELECT 1 FROM @TempLines)
    BEGIN
        RAISERROR('No temp sales lines found for this correction.', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM @TempLines WHERE ISNULL(ChangeStatus, '') NOT IN ('', 'U'))
    BEGIN
        RAISERROR('Drop-ship stage-3 correction cannot add or delete lines.', 16, 1);
        RETURN;
    END

    IF EXISTS
    (
        SELECT 1
        FROM @TempLines
        GROUP BY SalesDetailId
        HAVING SalesDetailId IS NULL OR COUNT(*) > 1
    )
    BEGIN
        RAISERROR('Temp sales lines must map one-to-one to existing sales detail lines.', 16, 1);
        RETURN;
    END

    IF (SELECT COUNT(*) FROM @TempLines) <> (SELECT COUNT(*) FROM SalesDetail WHERE SalesId = @SalesId)
    BEGIN
        RAISERROR('Drop-ship stage-3 correction cannot add or delete lines.', 16, 1);
        RETURN;
    END

    -- Prove this is the same line set. Only UnitPrice and Notes are allowed to differ.
    IF EXISTS
    (
        SELECT 1
        FROM @TempLines t
        LEFT JOIN SalesDetail sd ON sd.SalesDetailId = t.SalesDetailId
                                AND sd.SalesId = @SalesId
        WHERE sd.SalesDetailId IS NULL
           OR ISNULL(t.LineId, -2147483648) <> ISNULL(sd.LineId, -2147483648)
           OR ISNULL(t.LineType, '') <> ISNULL(sd.LineType, '')
           OR ISNULL(t.ItemId, -2147483648) <> ISNULL(sd.ItemId, -2147483648)
           OR ISNULL(t.AccountId, -2147483648) <> ISNULL(sd.AccountId, -2147483648)
           OR ISNULL(t.ItemUnitId, -2147483648) <> ISNULL(sd.ItemUnitId, -2147483648)
           OR ISNULL(t.Unit, '') <> ISNULL(sd.Unit, '')
           OR ISNULL(t.OrdQty, 0) <> ISNULL(sd.OrdQty, 0)
           OR ISNULL(t.ShipQty, 0) <> ISNULL(sd.ShipQty, 0)
           OR ISNULL(t.BillQty, 0) <> ISNULL(sd.BillQty, 0)
           OR ISNULL(t.IsTaxable, 0) <> ISNULL(sd.IsTaxable, 0)
           OR ISNULL(t.OrgPrice, 0) <> ISNULL(sd.OrgPrice, 0)
           OR ISNULL(t.DiscountPercent, 0) <> ISNULL(sd.DiscountPercent, 0)
           OR ISNULL(t.FactorToBase, 0) <> ISNULL(sd.FactorToBase, 0)
           OR ISNULL(t.CartLineType, '') <> ISNULL(sd.CartLineType, '')
           OR ISNULL(t.IsSystemManaged, 0) <> ISNULL(sd.IsSystemManaged, 0)
           OR ISNULL(t.DisplaySort, -2147483648) <> ISNULL(sd.DisplaySort, -2147483648)
           OR ISNULL(t.ExtTotal, 0) <> ROUND(ISNULL(sd.BillQty, 0) * ISNULL(t.UnitPrice, 0), 2)
    )
    BEGIN
        RAISERROR('Only price and comment can be changed on a stage-3 drop-ship sales order.', 16, 1);
        RETURN;
    END

    -- Prevent using comment edits to toggle the old FREE/OUT/CREDIT/CHARGE marker prefixes.
    IF EXISTS
    (
        SELECT 1
        FROM @TempLines t
        INNER JOIN SalesDetail sd ON sd.SalesDetailId = t.SalesDetailId
        CROSS APPLY
        (
            SELECT
                CASE
                    WHEN UPPER(LTRIM(ISNULL(sd.Notes, ''))) LIKE 'FREE.%' THEN 'FREE.'
                    WHEN UPPER(LTRIM(ISNULL(sd.Notes, ''))) LIKE 'OUT.%' THEN 'OUT.'
                    WHEN UPPER(LTRIM(ISNULL(sd.Notes, ''))) LIKE 'CREDIT.%' THEN 'CREDIT.'
                    WHEN UPPER(LTRIM(ISNULL(sd.Notes, ''))) LIKE 'CHARGE.%' THEN 'CHARGE.'
                    ELSE ''
                END AS OldMarker,
                CASE
                    WHEN UPPER(LTRIM(ISNULL(t.Notes, ''))) LIKE 'FREE.%' THEN 'FREE.'
                    WHEN UPPER(LTRIM(ISNULL(t.Notes, ''))) LIKE 'OUT.%' THEN 'OUT.'
                    WHEN UPPER(LTRIM(ISNULL(t.Notes, ''))) LIKE 'CREDIT.%' THEN 'CREDIT.'
                    WHEN UPPER(LTRIM(ISNULL(t.Notes, ''))) LIKE 'CHARGE.%' THEN 'CHARGE.'
                    ELSE ''
                END AS NewMarker
        ) marker
        WHERE marker.OldMarker <> marker.NewMarker
    )
    BEGIN
        RAISERROR('Free/out/credit/charge markers cannot be changed in this correction mode.', 16, 1);
        RETURN;
    END

    SELECT @NeedsReprint =
        CASE WHEN EXISTS
        (
            SELECT 1
            FROM @TempLines t
            INNER JOIN SalesDetail sd ON sd.SalesDetailId = t.SalesDetailId
            WHERE ISNULL(t.UnitPrice, 0) <> ISNULL(sd.UnitPrice, 0)
        ) THEN 1 ELSE 0 END;

    SET @LockResource = 'Sales_DropShipStage3PriceNoteUpdate_' + CONVERT(NVARCHAR(20), @SalesId);

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
        BEGIN
            RAISERROR('This sales order is already being updated.', 16, 1);
        END

        UPDATE sd
        SET
            sd.UnitPrice = t.UnitPrice,
            sd.ExtTotal = ROUND(ISNULL(sd.BillQty, 0) * ISNULL(t.UnitPrice, 0), 2),
            sd.Notes = t.Notes
        FROM SalesDetail sd
        INNER JOIN @TempLines t ON t.SalesDetailId = sd.SalesDetailId
        WHERE sd.SalesId = @SalesId
          AND
          (
              ISNULL(sd.UnitPrice, 0) <> ISNULL(t.UnitPrice, 0)
              OR ISNULL(sd.Notes, '') <> ISNULL(t.Notes, '')
          );

        IF @NeedsReprint = 1
        BEGIN
            -- Keep Sales-side totals and posted journal rows aligned with the new price.
            UPDATE tjd
            SET
                tjd.Qty = sd.BillQty,
                tjd.Price = sd.UnitPrice,
                tjd.BillQty = sd.ExtTotal,
                tjd.Amount = CASE WHEN sd.LineType = 'A' AND a.IsAccountDebit = 1 THEN -sd.ExtTotal ELSE ABS(sd.ExtTotal) END,
                tjd.CrDeAmount = crde.CrDeAmount,
                tjd.ItemId = sd.ItemId
            FROM SalesDetail sd
            INNER JOIN TransactionJournalDetail tjd ON tjd.TxId = @TxId
                                                    AND tjd.SourceDetailId = sd.SalesDetailId
            INNER JOIN Account a ON a.AccountId = tjd.AccountId
            CROSS APPLY
            (
                SELECT
                    CASE
                        WHEN sd.LineType = 'A'
                            THEN CASE WHEN a.IsAccountDebit = 1 THEN -sd.ExtTotal ELSE sd.ExtTotal END
                        ELSE ABS(sd.ExtTotal)
                    END AS Amount
            ) amt
            CROSS APPLY dbo.Fn_CrDeAmount(tjd.AccountId, amt.Amount) crde
            WHERE sd.SalesId = @SalesId
              AND
              (
                  sd.LineType = 'A'
                  OR tjd.AccountId IN
                  (
                      (SELECT AccountId FROM @AcctTable WHERE AccountCode = '@ISALE'),
                      (SELECT AccountId FROM @AcctTable WHERE AccountCode = '@ICREDIT')
                  )
              );

            UPDATE tjd
            SET
                tjd.Price = sd.UnitPrice,
                tjd.BillQty = sd.BillQty,
                tjd.ItemId = sd.ItemId,
                tjd.FactorToBase = sd.ShipQty
            FROM SalesDetail sd
            INNER JOIN TransactionJournalDetail tjd ON tjd.TxId = @TxId
                                                    AND tjd.SourceDetailId = sd.SalesDetailId
                                                    AND tjd.AccountId = (SELECT AccountId FROM @AcctTable WHERE AccountCode = '@INV')
            WHERE sd.SalesId = @SalesId;

            SELECT @SubTotal = ISNULL(SUM(ROUND(BillQty * UnitPrice, 2)), 0)
            FROM SalesDetail
            WHERE SalesId = @SalesId;

            SELECT @TaxableTotal = ISNULL(SUM(ROUND(BillQty * UnitPrice, 2)), 0)
            FROM SalesDetail
            WHERE SalesId = @SalesId
              AND IsTaxable = 1;

            SET @TaxTotal = ROUND(@TaxableTotal * ISNULL(@TaxPercent, 0), 2);
            SET @SalesTotal = @SubTotal + @TaxTotal;

            UPDATE Sales
            SET
                SubTotal = @SubTotal,
                TaxTotal = @TaxTotal,
                TaxableTotal = @TaxableTotal,
                SalesTotal = @SalesTotal,
                Updateby = @EmpId,
                UpdatedAt = GETUTCDATE()
            WHERE SalesId = @SalesId;

            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@AR';
            EXEC Fn_Adjust_CrDeAmount @AccountId, @SalesTotal, @CrDeAmount OUTPUT;

            UPDATE TransactionJournalDetail
            SET Amount = @SalesTotal,
                CrDeAmount = @CrDeAmount
            WHERE TxId = @TxId
              AND AccountId = @AccountId;

            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@FSTP';

            IF @TaxTotal <> 0
            BEGIN
                EXEC Fn_Adjust_CrDeAmount @AccountId, @TaxTotal, @CrDeAmount OUTPUT;

                IF NOT EXISTS (SELECT 1 FROM TransactionJournalDetail WHERE TxId = @TxId AND AccountId = @AccountId)
                BEGIN
                    INSERT INTO TransactionJournalDetail (TxId, AccountId, Amount, CrDeAmount)
                    VALUES (@TxId, @AccountId, @TaxTotal, @CrDeAmount);
                END
                ELSE
                BEGIN
                    UPDATE TransactionJournalDetail
                    SET Amount = @TaxTotal,
                        CrDeAmount = @CrDeAmount
                    WHERE TxId = @TxId
                      AND AccountId = @AccountId;
                END
            END
            ELSE
            BEGIN
                DELETE FROM TransactionJournalDetail
                WHERE TxId = @TxId
                  AND AccountId = @AccountId;
            END
        END
        ELSE
        BEGIN
            UPDATE Sales
            SET Updateby = @EmpId,
                UpdatedAt = GETUTCDATE()
            WHERE SalesId = @SalesId;
        END

        DELETE tsp
        FROM TempSalesPromo tsp
        WHERE EXISTS
        (
            SELECT 1
            FROM TempSales ts
            WHERE ts.PayeeId = @PayeeId
              AND ts.EmpId = @EmpId
              AND ts.SalesId = @SalesId
              AND
              (
                  ts.TempSalesId = tsp.OwnerTempSalesId
                  OR ts.TempSalesId = tsp.PromoTempSalesId
              )
        );

        DELETE TempSales
        WHERE PayeeId = @PayeeId
          AND EmpId = @EmpId
          AND SalesId = @SalesId;

        COMMIT TRANSACTION;

        IF @NeedsReprint = 1
        BEGIN
            EXEC Sales_CalcTotal @SalesId;
        END
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    EXEC dbo.Sales_GetAllList
        @Pageno = 1,
        @Pagesize = 1,
        @Search = NULL,
        @StartDate = NULL,
        @EndDate = NULL,
        @PayeeId = NULL,
        @ShipRoute = NULL,
        @Id = @SalesId,
        @Filterby = NULL,
        @EmpId = @EmpId,
        @SortField = NULL,
        @SortOrder = NULL,
        @IsCount = 0,
        @TotalCount = @TotalCount OUTPUT;
END
GO
