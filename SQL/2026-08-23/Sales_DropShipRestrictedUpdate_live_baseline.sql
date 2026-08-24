

-- DS-CLEAN-SO-EDIT 2026-08-22
-- Sales-only correction for drop-ship SO stages 2=Transit, 3=Received, and 4=Success.
-- Existing item lines may change selling price/comment only. User account lines may be
-- added, edited, or deleted. This procedure never writes Purchase or PurchaseDetail.
-- EXEC: DECLARE @NeedsReprint bit,@NeedsRevisedInvoiceEmail bit; EXEC dbo.Sales_DropShipRestrictedUpdate @SalesId=0,@EmpId=1,@NeedsReprint=@NeedsReprint OUTPUT,@NeedsRevisedInvoiceEmail=@NeedsRevisedInvoiceEmail OUTPUT; SELECT @NeedsReprint,@NeedsRevisedInvoiceEmail;
CREATE   PROCEDURE [dbo].[Sales_DropShipRestrictedUpdate]
    @SalesId INT,
    @EmpId INT,
    @NeedsReprint BIT OUTPUT,
    @NeedsRevisedInvoiceEmail BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NeedsReprint = 0;
    SET @NeedsRevisedInvoiceEmail = 0;

    DECLARE @SalesNumber INT;
    DECLARE @DocType CHAR(2);
    DECLARE @JournalDocType NVARCHAR(100);
    DECLARE @StageId INT;
    DECLARE @IsDropShip BIT;
    DECLARE @IsLocked BIT;
    DECLARE @PayeeId INT;
    DECLARE @DropShipPurchaseId INT;
    DECLARE @TaxPercent DECIMAL(18,4);
    DECLARE @PaymentApplied DECIMAL(18,2);
    DECLARE @DiscountApplied DECIMAL(18,2);
    DECLARE @SubTotal DECIMAL(18,2);
    DECLARE @TaxableTotal DECIMAL(18,2);
    DECLARE @TaxTotal DECIMAL(18,2);
    DECLARE @SalesTotal DECIMAL(18,2);
    DECLARE @AmountDue DECIMAL(18,2);
    DECLARE @TxId BIGINT;
    DECLARE @TxCount INT;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);
    DECLARE @TotalCount INT;
    DECLARE @ARAccountId INT;
    DECLARE @TaxAccountId INT;
    DECLARE @SaleAccountId INT;
    DECLARE @CreditAccountId INT;
    DECLARE @InventoryAccountId INT;
    DECLARE @HasDocumentChange BIT = 0;

    SELECT
        @PayeeId = s.ShipId,
        @DropShipPurchaseId = s.DropShipPurchaseId
    FROM dbo.Sales s
    WHERE s.SalesId = @SalesId;

    IF @PayeeId IS NULL
    BEGIN
        RAISERROR('Sales record not found.', 16, 1);
        RETURN;
    END

    SET @LockResource = 'DropShip_SOEdit_' + CONVERT(NVARCHAR(20), @SalesId);

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
        BEGIN
            RAISERROR('This drop-ship sales order is already being updated.', 16, 1);
        END

        -- Reread all authoritative state after the SO lock is held.
        SET @SalesNumber = NULL;
        SELECT
            @SalesNumber = s.SalesNumber,
            @DocType = s.DocType,
            @StageId = s.StageId,
            @IsDropShip = s.IsDropShip,
            @IsLocked = s.IsLocked,
            @PayeeId = s.ShipId,
            @DropShipPurchaseId = s.DropShipPurchaseId,
            @TaxPercent = s.TaxPercent,
            @PaymentApplied = ISNULL(s.PaymentApplied, 0),
            @DiscountApplied = ISNULL(s.DiscountApplied, 0)
        FROM dbo.Sales s
        WHERE s.SalesId = @SalesId;

        IF @SalesNumber IS NULL
        BEGIN
            RAISERROR('Sales record not found.', 16, 1);
        END

        IF ISNULL(@IsDropShip, 0) = 0 OR @DropShipPurchaseId IS NULL
        BEGIN
            RAISERROR('This is not a linked drop-ship sales order.', 16, 1);
        END

        IF ISNULL(@StageId, -1) NOT IN (2, 3, 4)
        BEGIN
            RAISERROR('Sales order stage changed. Reopen the order and use the current edit mode.', 16, 1);
        END

        IF ISNULL(@IsLocked, 0) = 1
        BEGIN
            RAISERROR('This sales order is locked and cannot be edited.', 16, 1);
        END

        IF @StageId = 4 AND (@PaymentApplied <> 0 OR @DiscountApplied <> 0)
        BEGIN
            RAISERROR('This completed sales order has payment or discount activity. Use the credit or adjustment workflow.', 16, 1);
        END

        -- Link ownership is required, but PO stage/reference/financial state never authorizes this sales-only edit.
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Purchase p
            WHERE p.PurchaseId = @DropShipPurchaseId
              AND ISNULL(p.IsDropShip, 0) = 1
              AND p.DropShipSalesId = @SalesId
        )
        BEGIN
            RAISERROR('Linked drop-ship purchase relationship was not found.', 16, 1);
        END

        DECLARE @TempLines TABLE
        (
            TempSalesId INT NOT NULL,
            SalesDetailId INT NULL,
            LineId INT NULL,
            LineType NVARCHAR(2) NOT NULL,
            ItemId INT NULL,
            AccountId INT NULL,
            ItemUnitId INT NULL,
            Unit NVARCHAR(50) NULL,
            OrdQty DECIMAL(18,2) NULL,
            ShipQty DECIMAL(18,2) NULL,
            BillQty DECIMAL(18,2) NULL,
            UnitPrice DECIMAL(18,4) NULL,
            Notes NVARCHAR(300) NULL,
            IsTaxable BIT NOT NULL,
            OrgPrice DECIMAL(18,4) NULL,
            DiscountPercent DECIMAL(18,4) NULL,
            FactorToBase DECIMAL(18,6) NULL,
            CartLineType NVARCHAR(30) NOT NULL,
            IsSystemManaged BIT NOT NULL,
            DisplaySort INT NULL
        );

        INSERT INTO @TempLines
            (TempSalesId, SalesDetailId, LineId, LineType, ItemId, AccountId, ItemUnitId, Unit,
             OrdQty, ShipQty, BillQty, UnitPrice, Notes, IsTaxable, OrgPrice,
             DiscountPercent, FactorToBase, CartLineType, IsSystemManaged, DisplaySort)
        SELECT
            ts.TempSalesId, ts.SalesDetailId, ts.LineId, ts.LineType, ts.ItemId, ts.AccountId,
            ts.ItemUnitId, ts.Unit, ts.OrdQty, ts.ShipQty, ts.BillQty, ts.UnitPrice, ts.Notes,
            ts.IsTaxable, ts.OrgPrice, ts.DiscountPercent, ts.FactorToBase,
            ISNULL(ts.CartLineType, 'MAIN'), ts.IsSystemManaged, ts.DisplaySort
        FROM dbo.TempSales ts
        WHERE ts.EmpId = @EmpId
          AND ts.PayeeId = @PayeeId
          AND ts.SalesId = @SalesId
          AND ISNULL(ts.IsStrike, 0) = 0
          AND ISNULL(ts.ChangeStatus, '') <> 'D';

        IF NOT EXISTS (SELECT 1 FROM @TempLines)
        BEGIN
            RAISERROR('No active temp sales lines found for this update.', 16, 1);
        END

        IF EXISTS
        (
            SELECT 1
            FROM @TempLines
            WHERE LineType NOT IN ('I', 'A')
               OR CartLineType <> 'MAIN'
        )
        BEGIN
            RAISERROR('Drop-ship later-stage edit does not support promotion, child, or unknown line types.', 16, 1);
        END

        IF EXISTS
        (
            SELECT 1
            FROM @TempLines
            WHERE SalesDetailId IS NOT NULL
            GROUP BY SalesDetailId
            HAVING COUNT(*) > 1
        )
        BEGIN
            RAISERROR('Temp sales detail mappings must be unique.', 16, 1);
        END

        IF EXISTS
        (
            SELECT 1
            FROM @TempLines
            GROUP BY LineId
            HAVING LineId IS NULL OR COUNT(*) > 1
        )
        BEGIN
            RAISERROR('Every active sales line must have a unique line number.', 16, 1);
        END

        -- Existing item lines must remain one-to-one. Price/comment are the only allowed differences.
        IF EXISTS
        (
            SELECT 1
            FROM dbo.SalesDetail sd
            LEFT JOIN @TempLines t ON t.SalesDetailId = sd.SalesDetailId AND t.LineType = 'I'
            WHERE sd.SalesId = @SalesId
              AND sd.LineType = 'I'
              AND t.TempSalesId IS NULL
        )
        OR EXISTS
        (
            SELECT 1
            FROM @TempLines t
            LEFT JOIN dbo.SalesDetail sd ON sd.SalesDetailId = t.SalesDetailId
                                        AND sd.SalesId = @SalesId
                                        AND sd.LineType = 'I'
            WHERE t.LineType = 'I'
              AND sd.SalesDetailId IS NULL
        )
        BEGIN
            RAISERROR('Item lines cannot be added or removed after Order stage.', 16, 1);
        END

        IF EXISTS
        (
            SELECT 1
            FROM @TempLines t
            INNER JOIN dbo.SalesDetail sd ON sd.SalesDetailId = t.SalesDetailId
                                          AND sd.SalesId = @SalesId
            WHERE t.LineType = 'I'
              AND
              (
                   ISNULL(t.LineId, -2147483648) <> ISNULL(sd.LineId, -2147483648)
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
              )
        )
        BEGIN
            RAISERROR('Only item selling price and comment can change after Order stage.', 16, 1);
        END

        -- System-managed rows must remain present and byte-for-field unchanged.
        IF EXISTS
        (
            SELECT 1
            FROM dbo.SalesDetail sd
            LEFT JOIN @TempLines t ON t.SalesDetailId = sd.SalesDetailId
            WHERE sd.SalesId = @SalesId
              AND ISNULL(sd.IsSystemManaged, 0) = 1
              AND
              (
                   t.TempSalesId IS NULL
                OR ISNULL(t.LineId, -2147483648) <> ISNULL(sd.LineId, -2147483648)
                OR ISNULL(t.LineType, '') <> ISNULL(sd.LineType, '')
                OR ISNULL(t.ItemId, -2147483648) <> ISNULL(sd.ItemId, -2147483648)
                OR ISNULL(t.AccountId, -2147483648) <> ISNULL(sd.AccountId, -2147483648)
                OR ISNULL(t.ItemUnitId, -2147483648) <> ISNULL(sd.ItemUnitId, -2147483648)
                OR ISNULL(t.Unit, '') <> ISNULL(sd.Unit, '')
                OR ISNULL(t.OrdQty, 0) <> ISNULL(sd.OrdQty, 0)
                OR ISNULL(t.ShipQty, 0) <> ISNULL(sd.ShipQty, 0)
                OR ISNULL(t.BillQty, 0) <> ISNULL(sd.BillQty, 0)
                OR ISNULL(t.UnitPrice, 0) <> ISNULL(sd.UnitPrice, 0)
                OR ISNULL(t.Notes, '') <> ISNULL(sd.Notes, '')
                OR ISNULL(t.IsTaxable, 0) <> ISNULL(sd.IsTaxable, 0)
              )
        )
        BEGIN
            RAISERROR('System-managed sales lines cannot be changed in this edit mode.', 16, 1);
        END

        -- Existing user account rows may change Account, amount (UnitPrice), and comment only.
        IF EXISTS
        (
            SELECT 1
            FROM @TempLines t
            LEFT JOIN dbo.SalesDetail sd ON sd.SalesDetailId = t.SalesDetailId
                                        AND sd.SalesId = @SalesId
            WHERE t.LineType = 'A'
              AND t.SalesDetailId IS NOT NULL
              AND ISNULL(t.IsSystemManaged, 0) = 0
              AND
              (
                   sd.SalesDetailId IS NULL
                OR sd.LineType <> 'A'
                OR ISNULL(sd.IsSystemManaged, 0) = 1
                OR ISNULL(t.LineId, -2147483648) <> ISNULL(sd.LineId, -2147483648)
                OR t.ItemId IS NOT NULL
                OR t.ItemUnitId IS NOT NULL
                OR ISNULL(t.OrdQty, 0) <> ISNULL(sd.OrdQty, 0)
                OR ISNULL(t.ShipQty, 0) <> ISNULL(sd.ShipQty, 0)
                OR ISNULL(t.BillQty, 0) <> ISNULL(sd.BillQty, 0)
                OR ISNULL(t.IsTaxable, 0) <> 0
                OR ISNULL(t.CartLineType, '') <> ISNULL(sd.CartLineType, '')
                OR ISNULL(t.IsSystemManaged, 0) <> 0
              )
        )
        BEGIN
            RAISERROR('Only account, amount, and comment can change on an existing account line.', 16, 1);
        END

        -- New account rows use the established one-unit sales amount shape.
        IF EXISTS
        (
            SELECT 1
            FROM @TempLines t
            WHERE t.LineType = 'A'
              AND t.SalesDetailId IS NULL
              AND
              (
                   t.AccountId IS NULL
                OR t.ItemId IS NOT NULL
                OR t.ItemUnitId IS NOT NULL
                OR ISNULL(t.OrdQty, 0) <> 1
                OR ISNULL(t.ShipQty, 0) <> 1
                OR ISNULL(t.BillQty, 0) <> 1
                OR ISNULL(t.IsTaxable, 0) <> 0
                OR ISNULL(t.IsSystemManaged, 0) <> 0
                OR ISNULL(t.CartLineType, '') <> 'MAIN'
              )
        )
        BEGIN
            RAISERROR('New account lines must use the standard one-unit, non-taxable account shape.', 16, 1);
        END

        IF EXISTS
        (
            SELECT 1
            FROM @TempLines t
            LEFT JOIN dbo.SalesDetail sd ON sd.SalesDetailId = t.SalesDetailId
                                        AND sd.SalesId = @SalesId
            LEFT JOIN dbo.Account a ON a.AccountId = t.AccountId
            LEFT JOIN dbo.AccountCategory ac ON ac.AccountCategoryId = a.AccountCategoryId
            WHERE t.LineType = 'A'
              AND (t.SalesDetailId IS NULL OR ISNULL(t.AccountId, 0) <> ISNULL(sd.AccountId, 0))
              AND (a.AccountId IS NULL OR ISNULL(a.Inactive, 0) = 1 OR ac.ClassCode IN ('A', 'X'))
        )
        BEGIN
            RAISERROR('New or changed account lines must use an active non-asset, non-expense account.', 16, 1);
        END

        -- Marker prefixes encode legacy line behavior and cannot be toggled through comment editing.
        IF EXISTS
        (
            SELECT 1
            FROM @TempLines t
            INNER JOIN dbo.SalesDetail sd ON sd.SalesDetailId = t.SalesDetailId
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
            RAISERROR('Free/out/credit/charge markers cannot be changed in this edit mode.', 16, 1);
        END

        SET @HasDocumentChange = CASE WHEN
            EXISTS
            (
                SELECT 1
                FROM @TempLines t
                INNER JOIN dbo.SalesDetail sd ON sd.SalesDetailId = t.SalesDetailId
                WHERE ISNULL(t.UnitPrice, 0) <> ISNULL(sd.UnitPrice, 0)
                   OR ISNULL(t.Notes, '') <> ISNULL(sd.Notes, '')
                   OR (t.LineType = 'A' AND ISNULL(t.AccountId, 0) <> ISNULL(sd.AccountId, 0))
            )
            OR EXISTS (SELECT 1 FROM @TempLines WHERE LineType = 'A' AND SalesDetailId IS NULL)
            OR EXISTS
            (
                SELECT 1
                FROM dbo.SalesDetail sd
                WHERE sd.SalesId = @SalesId
                  AND sd.LineType = 'A'
                  AND ISNULL(sd.IsSystemManaged, 0) = 0
                  AND NOT EXISTS (SELECT 1 FROM @TempLines t WHERE t.SalesDetailId = sd.SalesDetailId)
            )
            THEN 1 ELSE 0 END;

        -- Document actions follow the customer-facing stage: Transit saves quietly,
        -- Received may reprint, and Success may send a revised invoice.
        SET @NeedsReprint = CASE WHEN @StageId = 3 AND @HasDocumentChange = 1 THEN 1 ELSE 0 END;
        SET @NeedsRevisedInvoiceEmail = CASE WHEN @StageId = 4 AND @HasDocumentChange = 1 THEN 1 ELSE 0 END;

        UPDATE sd
        SET
            sd.UnitPrice = t.UnitPrice,
            sd.ExtTotal = ROUND(ISNULL(sd.BillQty, 0) * ISNULL(t.UnitPrice, 0), 2),
            sd.Notes = t.Notes
        FROM dbo.SalesDetail sd
        INNER JOIN @TempLines t ON t.SalesDetailId = sd.SalesDetailId
        WHERE sd.SalesId = @SalesId
          AND sd.LineType = 'I'
          AND ISNULL(sd.IsSystemManaged, 0) = 0;

        UPDATE sd
        SET
            sd.AccountId = t.AccountId,
            sd.UnitPrice = t.UnitPrice,
            sd.ExtTotal = ROUND(ISNULL(sd.BillQty, 0) * ISNULL(t.UnitPrice, 0), 2),
            sd.Notes = t.Notes,
            sd.IsTaxable = 0
        FROM dbo.SalesDetail sd
        INNER JOIN @TempLines t ON t.SalesDetailId = sd.SalesDetailId
        WHERE sd.SalesId = @SalesId
          AND sd.LineType = 'A'
          AND ISNULL(sd.IsSystemManaged, 0) = 0;

        DELETE sd
        FROM dbo.SalesDetail sd
        WHERE sd.SalesId = @SalesId
          AND sd.LineType = 'A'
          AND ISNULL(sd.IsSystemManaged, 0) = 0
          AND NOT EXISTS (SELECT 1 FROM @TempLines t WHERE t.SalesDetailId = sd.SalesDetailId);

        INSERT INTO dbo.SalesDetail
            (SalesId, LineId, LineType, ItemId, AccountId, ItemUnitId, Unit,
             OrdQty, ShipQty, BillQty, UnitPrice, ExtTotal, Notes, IsTaxable,
             OrgPrice, DiscountPercent, FactorToBase, CartLineType, IsSystemManaged, DisplaySort)
        SELECT
            @SalesId, t.LineId, 'A', NULL, t.AccountId, NULL, NULL,
            1, 1, 1, t.UnitPrice, ROUND(ISNULL(t.UnitPrice, 0), 2), t.Notes, 0,
            t.UnitPrice, 0, NULL, 'MAIN', 0, t.DisplaySort
        FROM @TempLines t
        WHERE t.LineType = 'A'
          AND t.SalesDetailId IS NULL;

        SELECT @SubTotal = ISNULL(SUM(ROUND(ISNULL(sd.BillQty, 0) * ISNULL(sd.UnitPrice, 0), 2)), 0)
        FROM dbo.SalesDetail sd
        WHERE sd.SalesId = @SalesId;

        SELECT @TaxableTotal = ISNULL(SUM(ROUND(ISNULL(sd.BillQty, 0) * ISNULL(sd.UnitPrice, 0), 2)), 0)
        FROM dbo.SalesDetail sd
        WHERE sd.SalesId = @SalesId
          AND sd.IsTaxable = 1;

        SET @TaxTotal = ROUND(@TaxableTotal * ISNULL(@TaxPercent, 0), 2);
        SET @SalesTotal = @SubTotal + @TaxTotal;
        SET @AmountDue = @SalesTotal - (ISNULL(@PaymentApplied, 0) + ISNULL(@DiscountApplied, 0));

        UPDATE dbo.Sales
        SET
            SubTotal = @SubTotal,
            TaxableTotal = @TaxableTotal,
            TaxTotal = @TaxTotal,
            SalesTotal = @SalesTotal,
            AmountDue = @AmountDue,
            Updateby = @EmpId,
            UpdatedAt = GETUTCDATE()
        WHERE SalesId = @SalesId;

        SET @JournalDocType = CASE
            WHEN @DocType = 'CM' THEN 'Sales Credit Memo'
            WHEN @DocType = 'DM' THEN 'Sales Debit Memo'
            ELSE 'Sales'
        END;

        SELECT
            @TxId = MAX(tj.TxId),
            @TxCount = COUNT(*)
        FROM dbo.TransactionJournal tj
        WHERE tj.SourceDocNumber = @SalesNumber
          AND tj.SourceDocType = @JournalDocType;

        IF ISNULL(@TxCount, 0) > 1
        BEGIN
            RAISERROR('Multiple sales journals were found for this sales order.', 16, 1);
        END

        IF @StageId = 4 AND @TxId IS NULL
        BEGIN
            RAISERROR('Completed drop-ship sales order is missing its required journal.', 16, 1);
        END

        IF @TxId IS NOT NULL
        BEGIN
            SELECT @ARAccountId = AccountId FROM dbo.Account WHERE AccountCode = '@AR';
            SELECT @TaxAccountId = AccountId FROM dbo.Account WHERE AccountCode = '@FSTP';
            SELECT @SaleAccountId = AccountId FROM dbo.Account WHERE AccountCode = '@ISALE';
            SELECT @CreditAccountId = AccountId FROM dbo.Account WHERE AccountCode = '@ICREDIT';
            SELECT @InventoryAccountId = AccountId FROM dbo.Account WHERE AccountCode = '@INV';

            IF @ARAccountId IS NULL OR @TaxAccountId IS NULL OR @SaleAccountId IS NULL
               OR @CreditAccountId IS NULL OR @InventoryAccountId IS NULL
            BEGIN
                RAISERROR('Required sales posting accounts are missing.', 16, 1);
            END

            DECLARE @JournalRows TABLE
            (
                RowId INT IDENTITY(1,1),
                SortGroup INT,
                LineSort INT,
                AccountId INT,
                PayeeId INT NULL,
                ItemId INT NULL,
                Qty DECIMAL(18,6) NULL,
                Price DECIMAL(18,6) NULL,
                BillQty DECIMAL(18,6) NULL,
                Amount DECIMAL(18,2),
                CrDeAmount DECIMAL(18,2),
                SourceDetailId INT NULL,
                FactorToBase DECIMAL(18,6) NULL
            );

            INSERT INTO @JournalRows (SortGroup, LineSort, AccountId, PayeeId, Amount, CrDeAmount)
            SELECT 0, 0, @ARAccountId, @PayeeId, @SalesTotal, f.CrDeAmount
            FROM dbo.Fn_CrDeAmount(@ARAccountId, @SalesTotal) f;

            IF @TaxTotal <> 0
            BEGIN
                INSERT INTO @JournalRows (SortGroup, LineSort, AccountId, Amount, CrDeAmount)
                SELECT 0, 1, @TaxAccountId, @TaxTotal, f.CrDeAmount
                FROM dbo.Fn_CrDeAmount(@TaxAccountId, @TaxTotal) f;
            END

            INSERT INTO @JournalRows
                (SortGroup, LineSort, AccountId, PayeeId, Qty, Price, BillQty,
                 Amount, CrDeAmount, SourceDetailId)
            SELECT
                1, sd.LineId, sd.AccountId, @PayeeId, sd.BillQty, sd.UnitPrice,
                line.LineAmount, line.LineAmount, f.CrDeAmount, sd.SalesDetailId
            FROM dbo.SalesDetail sd
            CROSS APPLY (SELECT ROUND(ISNULL(sd.BillQty, 0) * ISNULL(sd.UnitPrice, 0), 2) AS LineAmount) line
            CROSS APPLY dbo.Fn_CrDeAmount(sd.AccountId, line.LineAmount) f
            WHERE sd.SalesId = @SalesId
              AND sd.LineType = 'A';

            INSERT INTO @JournalRows
                (SortGroup, LineSort, AccountId, PayeeId, ItemId, Qty, Price, BillQty,
                 Amount, CrDeAmount, SourceDetailId, FactorToBase)
            SELECT
                1, sd.LineId, acct.AccountId, @PayeeId, sd.ItemId, sd.BillQty,
                sd.UnitPrice, line.LineAmount, line.LineAmount, f.CrDeAmount,
                sd.SalesDetailId, sd.FactorToBase
            FROM dbo.SalesDetail sd
            CROSS APPLY (SELECT ROUND(ISNULL(sd.BillQty, 0) * ISNULL(sd.UnitPrice, 0), 2) AS LineAmount) line
            CROSS APPLY
            (
                SELECT CASE WHEN line.LineAmount < 0 THEN @CreditAccountId ELSE @SaleAccountId END AS AccountId
            ) acct
            CROSS APPLY dbo.Fn_CrDeAmount(acct.AccountId, line.LineAmount) f
            WHERE sd.SalesId = @SalesId
              AND sd.LineType = 'I';

            IF ABS((SELECT ISNULL(SUM(CrDeAmount), 0) FROM @JournalRows)) >= 0.01
            BEGIN
                THROW 51020, 'Drop-ship sales journal is not balanced before restricted update.', 1;
            END

            DELETE FROM dbo.TransactionJournalDetail
            WHERE TxId = @TxId;

            INSERT INTO dbo.TransactionJournalDetail
                (TxId, AccountId, PayeeId, ItemId, Qty, Price, BillQty,
                 Amount, CrDeAmount, SourceDetailId, FactorToBase)
            SELECT
                @TxId, AccountId, PayeeId, ItemId, Qty, Price, BillQty,
                Amount, CrDeAmount, SourceDetailId, FactorToBase
            FROM @JournalRows
            ORDER BY SortGroup, LineSort, RowId;

            IF EXISTS
            (
                SELECT 1
                FROM dbo.TransactionJournalDetail
                WHERE TxId = @TxId
                  AND AccountId = @InventoryAccountId
            )
            BEGIN
                THROW 51021, 'Drop-ship sales journal cannot contain inventory rows.', 1;
            END

            IF ABS((SELECT ISNULL(SUM(CrDeAmount), 0) FROM dbo.TransactionJournalDetail WHERE TxId = @TxId)) >= 0.01
            BEGIN
                THROW 51022, 'Drop-ship sales journal is not balanced after restricted update.', 1;
            END
        END

        DELETE tsp
        FROM dbo.TempSalesPromo tsp
        WHERE EXISTS
        (
            SELECT 1
            FROM dbo.TempSales ts
            WHERE ts.PayeeId = @PayeeId
              AND ts.EmpId = @EmpId
              AND ts.SalesId = @SalesId
              AND (ts.TempSalesId = tsp.OwnerTempSalesId OR ts.TempSalesId = tsp.PromoTempSalesId)
        );

        DELETE FROM dbo.TempSales
        WHERE PayeeId = @PayeeId
          AND EmpId = @EmpId
          AND SalesId = @SalesId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
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