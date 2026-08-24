SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- DS-CLEAN-SO-EDIT 2026-08-22
-- Sales-only correction for drop-ship SO stages 2=Transit, 3=Received, and 4=Success.
-- Existing item lines may change selling price/comment only. User account lines may be
-- added, edited, or deleted. This procedure never writes Purchase or PurchaseDetail.
-- EXEC: DECLARE @NeedsReprint bit,@NeedsRevisedInvoiceEmail bit; EXEC dbo.Sales_DropShipRestrictedUpdate @SalesId=0,@EmpId=1,@NeedsReprint=@NeedsReprint OUTPUT,@NeedsRevisedInvoiceEmail=@NeedsRevisedInvoiceEmail OUTPUT; SELECT @NeedsReprint,@NeedsRevisedInvoiceEmail;
CREATE OR ALTER PROCEDURE [dbo].[Sales_DropShipRestrictedUpdate]
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

        CREATE TABLE #CartRows
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

        INSERT INTO #CartRows
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

        CREATE TABLE #SavedRows
        (
            SalesDetailId INT NOT NULL,
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

        INSERT INTO #SavedRows
            (SalesDetailId, LineId, LineType, ItemId, AccountId, ItemUnitId, Unit,
             OrdQty, ShipQty, BillQty, UnitPrice, Notes, IsTaxable, OrgPrice,
             DiscountPercent, FactorToBase, CartLineType, IsSystemManaged, DisplaySort)
        SELECT
            sd.SalesDetailId, sd.LineId, sd.LineType, sd.ItemId, sd.AccountId, sd.ItemUnitId,
            sd.Unit, sd.OrdQty, sd.ShipQty, sd.BillQty, sd.UnitPrice, sd.Notes, ISNULL(sd.IsTaxable, 0),
            sd.OrgPrice, sd.DiscountPercent, sd.FactorToBase, ISNULL(sd.CartLineType, 'MAIN'),
            ISNULL(sd.IsSystemManaged, 0), sd.DisplaySort
        FROM dbo.SalesDetail sd
        WHERE sd.SalesId = @SalesId;

        IF NOT EXISTS (SELECT 1 FROM #CartRows)
        BEGIN
            RAISERROR('No active temp sales lines found for this update.', 16, 1);
        END

        -- Basic cart shape: only main item/account rows with stable line mappings are accepted.
        IF EXISTS
        (
            SELECT 1
            FROM #CartRows
            WHERE LineType NOT IN ('I', 'A')
               OR CartLineType <> 'MAIN'
        )
        BEGIN
            RAISERROR('Drop-ship later-stage edit does not support promotion, child, or unknown line types.', 16, 1);
        END

        IF EXISTS
        (
            SELECT 1
            FROM #CartRows
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
            FROM #CartRows
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
            FROM #SavedRows s
            LEFT JOIN #CartRows c ON c.SalesDetailId = s.SalesDetailId
                                 AND c.LineType = 'I'
            WHERE s.LineType = 'I'
              AND c.TempSalesId IS NULL
        )
        OR EXISTS
        (
            SELECT 1
            FROM #CartRows c
            LEFT JOIN #SavedRows s ON s.SalesDetailId = c.SalesDetailId
                                  AND s.LineType = 'I'
            WHERE c.LineType = 'I'
              AND s.SalesDetailId IS NULL
        )
        BEGIN
            RAISERROR('Item lines cannot be added or removed after Order stage.', 16, 1);
        END

        IF EXISTS
        (
            SELECT 1
            FROM #CartRows c
            INNER JOIN #SavedRows s ON s.SalesDetailId = c.SalesDetailId
            WHERE c.LineType = 'I'
              AND EXISTS
              (
                  SELECT
                      c.LineId, c.ItemId, c.AccountId, c.ItemUnitId, c.Unit,
                      c.OrdQty, c.ShipQty, c.BillQty, c.IsTaxable, c.OrgPrice,
                      c.DiscountPercent, c.FactorToBase, c.CartLineType,
                      c.IsSystemManaged, c.DisplaySort
                  EXCEPT
                  SELECT
                      s.LineId, s.ItemId, s.AccountId, s.ItemUnitId, s.Unit,
                      s.OrdQty, s.ShipQty, s.BillQty, s.IsTaxable, s.OrgPrice,
                      s.DiscountPercent, s.FactorToBase, s.CartLineType,
                      s.IsSystemManaged, s.DisplaySort
              )
        )
        BEGIN
            RAISERROR('Only item selling price and comment can change after Order stage.', 16, 1);
        END

        -- System-managed rows must remain present and byte-for-field unchanged.
        IF EXISTS
        (
            SELECT 1
            FROM #SavedRows s
            LEFT JOIN #CartRows c ON c.SalesDetailId = s.SalesDetailId
            WHERE s.IsSystemManaged = 1
              AND
              (
                  c.TempSalesId IS NULL
                  OR EXISTS
                  (
                      SELECT
                          c.LineId, c.LineType, c.ItemId, c.AccountId, c.ItemUnitId,
                          c.Unit, c.OrdQty, c.ShipQty, c.BillQty, c.UnitPrice,
                          c.Notes, c.IsTaxable
                      EXCEPT
                      SELECT
                          s.LineId, s.LineType, s.ItemId, s.AccountId, s.ItemUnitId,
                          s.Unit, s.OrdQty, s.ShipQty, s.BillQty, s.UnitPrice,
                          s.Notes, s.IsTaxable
                  )
              )
        )
        BEGIN
            RAISERROR('System-managed sales lines cannot be changed in this edit mode.', 16, 1);
        END

        -- Existing user account rows may change Account, amount (UnitPrice), and comment only.
        IF EXISTS
        (
            SELECT 1
            FROM #CartRows c
            LEFT JOIN #SavedRows s ON s.SalesDetailId = c.SalesDetailId
            WHERE c.LineType = 'A'
              AND c.SalesDetailId IS NOT NULL
              AND c.IsSystemManaged = 0
              AND
              (
                  s.SalesDetailId IS NULL
                  OR s.LineType <> 'A'
                  OR s.IsSystemManaged = 1
                  OR EXISTS
                  (
                      SELECT
                          c.LineId, c.ItemId, c.ItemUnitId, c.OrdQty, c.ShipQty,
                          c.BillQty, c.IsTaxable, c.CartLineType, c.IsSystemManaged
                      EXCEPT
                      SELECT
                          s.LineId, s.ItemId, s.ItemUnitId, s.OrdQty, s.ShipQty,
                          s.BillQty, CONVERT(BIT, 0), s.CartLineType, CONVERT(BIT, 0)
                  )
              )
        )
        BEGIN
            RAISERROR('Only account, amount, and comment can change on an existing account line.', 16, 1);
        END

        -- New account rows use the established one-unit sales amount shape.
        IF EXISTS
        (
            SELECT 1
            FROM #CartRows c
            WHERE c.LineType = 'A'
              AND c.SalesDetailId IS NULL
              AND
              (
                   c.AccountId IS NULL
                OR c.ItemId IS NOT NULL
                OR c.ItemUnitId IS NOT NULL
                OR ISNULL(c.OrdQty, 0) <> 1
                OR ISNULL(c.ShipQty, 0) <> 1
                OR ISNULL(c.BillQty, 0) <> 1
                OR c.IsTaxable <> 0
                OR c.IsSystemManaged <> 0
                OR c.CartLineType <> 'MAIN'
              )
        )
        BEGIN
            RAISERROR('New account lines must use the standard one-unit, non-taxable account shape.', 16, 1);
        END

        IF EXISTS
        (
            SELECT 1
            FROM #CartRows c
            LEFT JOIN #SavedRows s ON s.SalesDetailId = c.SalesDetailId
            LEFT JOIN dbo.Account a ON a.AccountId = c.AccountId
            LEFT JOIN dbo.AccountCategory ac ON ac.AccountCategoryId = a.AccountCategoryId
            WHERE c.LineType = 'A'
              AND (c.SalesDetailId IS NULL OR ISNULL(c.AccountId, 0) <> ISNULL(s.AccountId, 0))
              AND (a.AccountId IS NULL OR ISNULL(a.Inactive, 0) = 1 OR ac.ClassCode IN ('A', 'X'))
        )
        BEGIN
            RAISERROR('New or changed account lines must use an active non-asset, non-expense account.', 16, 1);
        END

        -- Marker prefixes encode legacy line behavior and cannot be toggled through comment editing.
        IF EXISTS
        (
            SELECT 1
            FROM #CartRows c
            INNER JOIN #SavedRows s ON s.SalesDetailId = c.SalesDetailId
            CROSS APPLY
            (
                SELECT
                    CASE
                        WHEN UPPER(LTRIM(ISNULL(s.Notes, ''))) LIKE 'FREE.%' THEN 'FREE.'
                        WHEN UPPER(LTRIM(ISNULL(s.Notes, ''))) LIKE 'OUT.%' THEN 'OUT.'
                        WHEN UPPER(LTRIM(ISNULL(s.Notes, ''))) LIKE 'CREDIT.%' THEN 'CREDIT.'
                        WHEN UPPER(LTRIM(ISNULL(s.Notes, ''))) LIKE 'CHARGE.%' THEN 'CHARGE.'
                        ELSE ''
                    END AS OldMarker,
                    CASE
                        WHEN UPPER(LTRIM(ISNULL(c.Notes, ''))) LIKE 'FREE.%' THEN 'FREE.'
                        WHEN UPPER(LTRIM(ISNULL(c.Notes, ''))) LIKE 'OUT.%' THEN 'OUT.'
                        WHEN UPPER(LTRIM(ISNULL(c.Notes, ''))) LIKE 'CREDIT.%' THEN 'CREDIT.'
                        WHEN UPPER(LTRIM(ISNULL(c.Notes, ''))) LIKE 'CHARGE.%' THEN 'CHARGE.'
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
                FROM #CartRows c
                INNER JOIN #SavedRows s ON s.SalesDetailId = c.SalesDetailId
                WHERE EXISTS (SELECT c.UnitPrice EXCEPT SELECT s.UnitPrice)
                   OR EXISTS (SELECT c.Notes EXCEPT SELECT s.Notes)
                   OR (c.LineType = 'A' AND EXISTS (SELECT c.AccountId EXCEPT SELECT s.AccountId))
            )
            OR EXISTS (SELECT 1 FROM #CartRows WHERE LineType = 'A' AND SalesDetailId IS NULL)
            OR EXISTS
            (
                SELECT 1
                FROM #SavedRows s
                WHERE s.LineType = 'A'
                  AND s.IsSystemManaged = 0
                  AND NOT EXISTS (SELECT 1 FROM #CartRows c WHERE c.SalesDetailId = s.SalesDetailId)
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
        INNER JOIN #CartRows t ON t.SalesDetailId = sd.SalesDetailId
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
        INNER JOIN #CartRows t ON t.SalesDetailId = sd.SalesDetailId
        WHERE sd.SalesId = @SalesId
          AND sd.LineType = 'A'
          AND ISNULL(sd.IsSystemManaged, 0) = 0;

        DELETE sd
        FROM dbo.SalesDetail sd
        WHERE sd.SalesId = @SalesId
          AND sd.LineType = 'A'
          AND ISNULL(sd.IsSystemManaged, 0) = 0
          AND NOT EXISTS (SELECT 1 FROM #CartRows t WHERE t.SalesDetailId = sd.SalesDetailId);

        INSERT INTO dbo.SalesDetail
            (SalesId, LineId, LineType, ItemId, AccountId, ItemUnitId, Unit,
             OrdQty, ShipQty, BillQty, UnitPrice, ExtTotal, Notes, IsTaxable,
             OrgPrice, DiscountPercent, FactorToBase, CartLineType, IsSystemManaged, DisplaySort)
        SELECT
            @SalesId, t.LineId, 'A', NULL, t.AccountId, NULL, NULL,
            1, 1, 1, t.UnitPrice, ROUND(ISNULL(t.UnitPrice, 0), 2), t.Notes, 0,
            t.UnitPrice, 0, NULL, 'MAIN', 0, t.DisplaySort
        FROM #CartRows t
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
