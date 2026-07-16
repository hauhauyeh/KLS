-- KLS-4DP-B-Phase2-Slice2-DropShipment_ConvertPOToBill: Class-A pass-through ROUND flip (unconditional, inert).
--   Flip the purchase-side journal-Price write ROUND(pd.FinalPrice,2) -> ROUND(pd.FinalPrice,4). Entered goods
--   price (<=2dp today) -> byte-identical now. All money ROUND(qty*price,2) amounts LEFT at 2dp.
-- 2026-07-13 DSCC-FIX: drop-ship cost-clearing moved @APDS (Liability/AP) -> @DSCC (Asset/Inventory, debit-nature).
--   Two CrDe helper sign flips compensate the opposite IsAccountDebit so CrDeAmount (the signed side) is UNCHANGED;
--   the purchase clearing-row Amount is corrected from signed-negative to the positive business magnitude (a latent
--   pre-existing bug). Plus a required-account guard (missing or inactive). See
--   plan-dropship-1-posting-DSCC.md. Deploy DropShipment_DSCC_seed.sql FIRST.
CREATE   PROCEDURE [dbo].[DropShipment_ConvertPOToBill]
    @PurchaseId INT,
    @EmpId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IsDropShip BIT=0;
    DECLARE @PurchaseStageId INT;
    DECLARE @SalesId INT;
    DECLARE @SalesStageId INT;
    DECLARE @PurchaseNumber INT;
    DECLARE @SalesNumber INT;
    DECLARE @PayeeId INT;           -- customer PayeeId (ShipId on Sales)
    DECLARE @VendorPayeeId INT;
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);

    -- Purchase-side journal vars
    DECLARE @PurTxId BIGINT;
    DECLARE @PurDocOrder INT;
    DECLARE @PurDocType NVARCHAR(100) = 'Purchase';
    DECLARE @PurFinalTotal DECIMAL(18,2);
    DECLARE @PurBillTotal DECIMAL(18,2);
    DECLARE @CrDeAmount DECIMAL(18,2) = 0;
    DECLARE @AccountId INT;

    -- Sales-side journal vars
    DECLARE @SalTxId BIGINT;
    DECLARE @SalDocOrder INT;
    DECLARE @SalDocType NVARCHAR(100) = 'Sales';
    DECLARE @ShipDate DATE;
    DECLARE @TaxRate DECIMAL(18,4);
    DECLARE @SubTotal DECIMAL(18,2);
    DECLARE @TaxableTotal DECIMAL(18,2);
    DECLARE @TaxTotal DECIMAL(18,2);
    DECLARE @SalesTotal DECIMAL(18,2);
    DECLARE @COGSTotal DECIMAL(18,2);
    DECLARE @SalesTotalOut DECIMAL(18,2);

    DECLARE @InvoiceDate DATE = CAST(GETDATE() AS DATE);

    -- Resolve account IDs
    DECLARE @AcctTable AS TABLE (
        Id INT IDENTITY(1,1),
        AccountCode NVARCHAR(50),
        AccountId INT
    );
    INSERT INTO @AcctTable(AccountCode) VALUES('@AP');
    INSERT INTO @AcctTable(AccountCode) VALUES('@DSCC');
    INSERT INTO @AcctTable(AccountCode) VALUES('@AR');
    INSERT INTO @AcctTable(AccountCode) VALUES('@FSTP');
    INSERT INTO @AcctTable(AccountCode) VALUES('@ISALE');
    INSERT INTO @AcctTable(AccountCode) VALUES('@ICREDIT');
    INSERT INTO @AcctTable(AccountCode) VALUES('@COGS');

    UPDATE t SET t.AccountId = a.AccountId
    FROM @AcctTable AS t
    INNER JOIN Account AS a ON t.AccountCode = a.AccountCode
                           AND ISNULL(a.Inactive, 0) = 0;   -- 2026-07-13 DSCC-FIX: inactive account won't resolve -> null-guard fires

    -- 2026-07-13 DSCC-FIX: fail-fast if any required posting account did not resolve -- MISSING or INACTIVE
    -- (e.g. @DSCC removed/deactivated after a restore). Prevents a dropped clearing row / zero CrDeAmount -> corrupted journal.
    IF EXISTS (SELECT 1 FROM @AcctTable WHERE AccountId IS NULL)
        THROW 51001, 'Required posting account missing or inactive (check @DSCC seed).', 1;

    -- Validate purchase
    SELECT
        @IsDropShip = IsDropShip,
        @PurchaseStageId = StageId,
        @SalesId = DropShipSalesId,
        @PurchaseNumber = PurchaseNumber,
        @VendorPayeeId = PayeeId
    FROM Purchase
    WHERE PurchaseId = @PurchaseId;

    IF @IsDropShip = 0
    BEGIN
        RAISERROR('This is not a drop-ship purchase. Use the standard purchase workflow.', 16, 1);
        RETURN;
    END

    IF @PurchaseStageId <> 1
    BEGIN
        RAISERROR('Purchase is not in PO stage. Cannot convert to bill.', 16, 1);
        RETURN;
    END

    IF @SalesId IS NULL
    BEGIN
        RAISERROR('Linked sales order not found on this drop-ship purchase.', 16, 1);
        RETURN;
    END

    -- Validate linked sales
    SELECT
        @SalesStageId = StageId,
        @SalesNumber = SalesNumber,
        @PayeeId = ShipId,
        @ShipDate = ShipDate,
        @TaxRate = TaxPercent
    FROM Sales
    WHERE SalesId = @SalesId;

    IF @SalesStageId IS NULL
    BEGIN
        RAISERROR('Linked sales order not found.', 16, 1);
        RETURN;
    END

    IF @SalesStageId NOT IN (0, 3)
    BEGIN
        RAISERROR('Linked sales order is not in Order or Transit stage.', 16, 1);
        RETURN;
    END

    -- Resolve doc orders
    EXEC [Get_SourceDocOrder] @PurDocType, @PurDocOrder OUTPUT;
    EXEC [Get_SourceDocOrder] @SalDocType, @SalDocOrder OUTPUT;

    SET @LockResource =
        'DropShip_ConvertPOToBill_'
        + CONVERT(NVARCHAR(20), @PurchaseId);

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC @LockResult = sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
        BEGIN
            RAISERROR('This Convert to Bill is already being processed.', 16, 1);
        END

        -- ============================================================
        -- STEP 1: Fill quantity fields on PurchaseDetail
        -- ============================================================

        IF @SalesStageId = 0
        BEGIN
            -- From Order stage: auto-fill all qty fields
            UPDATE PurchaseDetail SET
                ShipQty = OrdQty0,
                BillQty = OrdQty0,
                ReceiveQty = OrdQty1,
                FinalQty = OrdQty1
                -- 2026-07-05 (Phase B): base qty moved to the shared ItemUnit-derived producer after
                -- this IF/ELSE (below). Prior (snapshot factor):
                -- BaseReceiveQty = ROUND(ISNULL(OrdQty1, 0) / NULLIF(FactorToBase, 0), 6),
                -- BaseFinalQty = ROUND(ISNULL(OrdQty1, 0) / NULLIF(FactorToBase, 0), 6)
            WHERE PurchaseId = @PurchaseId;
        END
        ELSE
        BEGIN
            -- From Transit stage: ShipQty already set, fill remaining
            UPDATE PurchaseDetail SET
                BillQty = OrdQty0,
                ReceiveQty = OrdQty1,
                FinalQty = OrdQty1
                -- 2026-07-05 (Phase B): base qty moved to the shared ItemUnit-derived producer after
                -- this IF/ELSE (below). Prior (snapshot factor):
                -- BaseReceiveQty = ROUND(ISNULL(OrdQty1, 0) / NULLIF(FactorToBase, 0), 6),
                -- BaseFinalQty = ROUND(ISNULL(OrdQty1, 0) / NULLIF(FactorToBase, 0), 6)
            WHERE PurchaseId = @PurchaseId;
        END

        -- 2026-07-05 (Phase B): PurchaseDetail base qty from ItemUnitId -> ItemUnit (Fn_QtyToBase),
        -- qty-only. Runs after both branch fills set ReceiveQty=FinalQty=OrdQty1, before STEP 2 reads
        -- pd.BaseFinalQty. INNER JOIN = item lines only; account lines (no ItemUnitId) not updated ->
        -- not consumed on the purchase side (@DSCC is LineType<>'A'; account rows use FinalQty*FinalPrice).
        UPDATE pd
        SET pd.BaseReceiveQty = dbo.Fn_QtyToBase(pd.ReceiveQty, iu.MultipleToBase, iu.FactorToBase),
            pd.BaseFinalQty   = dbo.Fn_QtyToBase(pd.FinalQty,   iu.MultipleToBase, iu.FactorToBase)
        FROM PurchaseDetail pd
        INNER JOIN ItemUnit iu ON iu.ItemUnitId = pd.ItemUnitId
        WHERE pd.PurchaseId = @PurchaseId;

        -- Calculate purchase total from filled quantities
        SELECT
			@PurBillTotal = ISNULL(SUM(ROUND(BillQty * BillPrice, 2)), 0),
			@PurFinalTotal = ISNULL(SUM(ROUND(FinalQty * FinalPrice, 2)), 0)
		FROM PurchaseDetail
		WHERE PurchaseId = @PurchaseId;

        -- ============================================================
        -- STEP 2: Purchase-side posting (DR @DSCC, CR @AP)
        -- ============================================================

        CREATE TABLE #PurTxDetail (
            TxDetailId INT IDENTITY(1,1),
            SortLine INT,
            RowSort INT,
            TxId BIGINT,
            AccountId INT,
            PayeeId INT,
            ItemId INT,
            Qty DECIMAL(18,6),
            Price DECIMAL(18,6),
            BillQty DECIMAL(18,6),
            Amount DECIMAL(18,2),
            CrDeAmount DECIMAL(18,2),
            SrcDetailId INT,
            FactorToBase DECIMAL(18,6)
        );

        INSERT INTO [dbo].[TransactionJournal]
            ([TxDate], [TxTime], [SourceDocOrder], [SourceDocType], [SourceDocNumber])
        VALUES
            (@InvoiceDate, GETUTCDATE(), @PurDocOrder, @PurDocType, @PurchaseNumber);

        SET @PurTxId = SCOPE_IDENTITY();

        -- @AP header row (credit side)
        SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@AP';
        EXEC Fn_Adjust_CrDeAmount @AccountId, @PurFinalTotal, @CrDeAmount OUTPUT;

        INSERT INTO #PurTxDetail
            ([SortLine], [RowSort], [TxId], [AccountId], [PayeeId], [Amount], [CrDeAmount])
        VALUES
            (0, 1, @PurTxId, @AccountId, @VendorPayeeId, @PurFinalTotal, @CrDeAmount);

        -- @DSCC per-line rows (debit side) ??" one row per PurchaseDetail line
        INSERT INTO #PurTxDetail
            ([SortLine], [RowSort], [TxId], [AccountId], [PayeeId], [ItemId],
             [Qty], [Price], [BillQty], [Amount], [CrDeAmount], [SrcDetailId], [FactorToBase])
        SELECT
            pd.PurchaseDetailId,
            1,
            @PurTxId,
            dscc.AccountId,
            @VendorPayeeId,
            pd.ItemId,
            pd.FinalQty,
            -- 4dp Slice-2: entered goods Price -> 4dp. was ROUND(pd.FinalPrice, 2)
            ROUND(pd.FinalPrice, 4),
            pd.BaseFinalQty,
            ABS(ROUND(pd.FinalQty * pd.FinalPrice, 2)),  -- 2026-07-13 DSCC-FIX: Amount = positive cost magnitude (was crde.CrDeAmount = signed -ve; pre-existing clearing-row bug, latent under @APDS)
            crde.CrDeAmount,
            pd.PurchaseDetailId,
            pd.FactorToBase
        FROM PurchaseDetail pd
        CROSS APPLY (SELECT AccountId FROM @AcctTable WHERE AccountCode = '@DSCC') dscc
        CROSS APPLY dbo.Fn_CrDeAmount
		(
			CONVERT(NVARCHAR(20), dscc.AccountId),
			ABS(ROUND(pd.FinalQty * pd.FinalPrice,2))  -- 2026-07-13 DSCC-FIX: +input -> debit (debit-nature @DSCC); was -ABS for credit-nature @APDS
		) crde
        WHERE pd.PurchaseId = @PurchaseId
          AND pd.LineType <> 'A';

        -- Account-type lines (LineType = 'A') for purchase
        INSERT INTO #PurTxDetail
            ([SortLine], [RowSort], [TxId], [AccountId], [PayeeId],
             [Amount], [CrDeAmount], [SrcDetailId])
        SELECT
            pd.PurchaseDetailId,
            1,
            @PurTxId,
            pd.AccountId,
            @VendorPayeeId,
            ABS(CASE WHEN a.IsAccountDebit = 1
                THEN ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)
                ELSE -ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)
            END),
            CASE WHEN a.IsAccountDebit = 1
                THEN -ABS(ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2))
                ELSE -ABS(ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2))
            END,
            pd.PurchaseDetailId
        FROM PurchaseDetail pd
        INNER JOIN Account a ON a.AccountId = pd.AccountId
        WHERE pd.PurchaseId = @PurchaseId
          AND pd.LineType = 'A';

        -- Write purchase journal rows
        INSERT INTO TransactionJournalDetail
            ([TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
             [Amount], [CrDeAmount], [SourceDetailId], [FactorToBase])
        SELECT
            [TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
            [Amount], [CrDeAmount], [SrcDetailId], [FactorToBase]
        FROM #PurTxDetail
        ORDER BY SortLine, RowSort, TxDetailId;

        -- Update purchase header
        UPDATE Purchase SET
            StageId = 6,
            ArrivalDate = @InvoiceDate,
            InvoiceDate = @InvoiceDate,
            VendorTotal = @PurBillTotal,
            PurchaseTotal = @PurFinalTotal,
            UpdatedAt = GETUTCDATE()
        WHERE PurchaseId = @PurchaseId;

        -- ============================================================
        -- STEP 3: Sales-side posting (DR @AR, CR Revenue, DR @COGS, CR @DSCC)
        -- ============================================================

        -- Recalculate sales totals from SalesDetail
        SELECT @SubTotal = ISNULL(SUM(ROUND(ISNULL(BillQty, 0) * ISNULL(UnitPrice, 0), 2)), 0)
        FROM SalesDetail WHERE SalesId = @SalesId;

        SELECT @TaxableTotal = ISNULL(SUM(ROUND(ISNULL(BillQty, 0) * ISNULL(UnitPrice, 0), 2)), 0)
        FROM SalesDetail WHERE SalesId = @SalesId AND IsTaxable = 1;

        SET @TaxTotal = ROUND(@TaxableTotal * ISNULL(@TaxRate, 0), 2);
        SET @SalesTotal = @SubTotal + @TaxTotal;

        -- COGS from linked PurchaseDetail (document-level)
        SET @COGSTotal = @PurFinalTotal;

        -- Refresh base quantities on SalesDetail
        -- 2026-07-04 (Phase B): base qty from ItemUnitId -> ItemUnit (source of truth) via
        -- dbo.Fn_QtyToBase. INNER JOIN = item lines only; account lines (no ItemUnitId) keep
        -- base qty untouched. Identity today (all MultipleToBase=1 => qty/factor). Prior block:
        -- UPDATE SalesDetail SET
        --     BaseOrdQty  = ROUND(OrdQty  / NULLIF(FactorToBase, 0), 6),
        --     BaseShipQty = ROUND(ShipQty / NULLIF(FactorToBase, 0), 6),
        --     BaseBillQty = ROUND(BillQty / NULLIF(FactorToBase, 0), 6)
        -- WHERE SalesId = @SalesId;
        UPDATE sd SET
            sd.BaseOrdQty  = dbo.Fn_QtyToBase(sd.OrdQty,  iu.MultipleToBase, iu.FactorToBase),
            sd.BaseShipQty = dbo.Fn_QtyToBase(sd.ShipQty, iu.MultipleToBase, iu.FactorToBase),
            sd.BaseBillQty = dbo.Fn_QtyToBase(sd.BillQty, iu.MultipleToBase, iu.FactorToBase)
        FROM SalesDetail sd
        INNER JOIN ItemUnit iu ON iu.ItemUnitId = sd.ItemUnitId
        WHERE sd.SalesId = @SalesId;

        -- Fill ShipQty = BillQty on SalesDetail if not already set
        UPDATE SalesDetail SET
            ShipQty = BillQty
        WHERE SalesId = @SalesId AND (ShipQty IS NULL OR ShipQty = 0);

        CREATE TABLE #SalTxDetail (
            TxDetailId INT IDENTITY(1,1),
            SortGroup INT,
            LineSort INT,
            RowSort INT,
            TxId BIGINT,
            AccountId INT,
            PayeeId INT,
            ItemId INT,
            Qty DECIMAL(18,6),
            Price DECIMAL(18,6),
            BillQty DECIMAL(18,6),
            FactorToBase DECIMAL(18,6),
            Amount DECIMAL(18,2),
            CrDeAmount DECIMAL(18,2),
            SrcDetailId INT
        );

        INSERT INTO [dbo].[TransactionJournal]
            ([TxDate], [TxTime], [SourceDocOrder], [SourceDocType], [SourceDocNumber])
        VALUES
            (@ShipDate, GETUTCDATE(), @SalDocOrder, @SalDocType, @SalesNumber);

        SET @SalTxId = SCOPE_IDENTITY();

        -- @AR header row
        SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@AR';
        EXEC Fn_Adjust_CrDeAmount @AccountId, @SalesTotal, @CrDeAmount OUTPUT;

        INSERT INTO #SalTxDetail
            ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [PayeeId], [Amount], [CrDeAmount])
        VALUES
            (0, 0, 1, @SalTxId, @AccountId, @PayeeId, @SalesTotal, @CrDeAmount);

        -- Tax row if applicable
        IF @TaxTotal <> 0
        BEGIN
            SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@FSTP';
            EXEC Fn_Adjust_CrDeAmount @AccountId, @TaxTotal, @CrDeAmount OUTPUT;

            INSERT INTO #SalTxDetail
                ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [Amount], [CrDeAmount])
            VALUES
                (0, 0, 2, @SalTxId, @AccountId, @TaxTotal, @CrDeAmount);
        END

        -- Revenue rows per SalesDetail line (account lines)
        INSERT INTO #SalTxDetail
            ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [PayeeId],
             [Qty], [Price], [BillQty], [Amount], [CrDeAmount], [SrcDetailId])
        SELECT
            1,
            sd.LineId,
            1,
            @SalTxId,
            sd.AccountId,
            @PayeeId,
            sd.BillQty,
            sd.UnitPrice,
            ROUND(sd.BillQty * sd.UnitPrice, 2),
            ROUND(sd.BillQty * sd.UnitPrice, 2),
            CASE WHEN a.IsAccountDebit = 1
                 THEN -ROUND(sd.BillQty * sd.UnitPrice, 2)
                 ELSE  ROUND(sd.BillQty * sd.UnitPrice, 2)
            END,
            sd.SalesDetailId
        FROM SalesDetail sd
        INNER JOIN Account a ON sd.AccountId = a.AccountId
        WHERE sd.SalesId = @SalesId AND sd.LineType = 'A';

        -- Revenue rows per SalesDetail line (item lines ??" both inventory and non-inventory)
        -- For drop-ship, all items use the same revenue pattern (no @INV rows)
        INSERT INTO #SalTxDetail
            ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [PayeeId],
             [ItemId], [Qty], [Price], [BillQty], [Amount], [CrDeAmount], [SrcDetailId], [FactorToBase])
        SELECT
            1,
            sd.LineId,
            1,
            @SalTxId,
            acct.AccountId,
            @PayeeId,
            sd.ItemId,
            sd.BillQty,
            sd.UnitPrice,
            ROUND(sd.BillQty * sd.UnitPrice, 2),
            ROUND(sd.BillQty * sd.UnitPrice, 2),
            CASE WHEN a.IsAccountDebit = 1
                 THEN -ROUND(sd.BillQty * sd.UnitPrice, 2)
                 ELSE  ROUND(sd.BillQty * sd.UnitPrice, 2)
            END,
            sd.SalesDetailId,
            sd.FactorToBase
        FROM SalesDetail sd
        CROSS APPLY (
            SELECT AccountId FROM @AcctTable
            WHERE AccountCode = CASE
                WHEN ROUND(sd.BillQty * sd.UnitPrice, 2) < 0 THEN '@ICREDIT'
                ELSE '@ISALE'
            END
        ) acct
        INNER JOIN Account a ON acct.AccountId = a.AccountId
        WHERE sd.SalesId = @SalesId AND sd.LineType <> 'A';

        -- COGS row: DR @COGS for total purchase cost (document-level)
        SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@COGS';
        EXEC Fn_Adjust_CrDeAmount @AccountId, @COGSTotal, @CrDeAmount OUTPUT;

        INSERT INTO #SalTxDetail
            ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [PayeeId],
             [Amount], [CrDeAmount])
        VALUES
            (2, 0, 1, @SalTxId, @AccountId, @PayeeId, @COGSTotal, @CrDeAmount);

        -- CR @DSCC for COGS (clearing account nets to zero)
        SELECT @AccountId = AccountId FROM @AcctTable WHERE AccountCode = '@DSCC';
        -- 2026-07-13 DSCC-FIX: @DSCC is debit-nature (opposite @APDS); feed NEGATIVE cost so the helper returns a credit.
        -- EXEC args cannot be expressions, so negate via a variable. The stored Amount below stays +@COGSTotal.
        DECLARE @NegCOGSTotal DECIMAL(18,2) = -@COGSTotal;
        EXEC Fn_Adjust_CrDeAmount @AccountId, @NegCOGSTotal, @CrDeAmount OUTPUT;

        INSERT INTO #SalTxDetail
            ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [PayeeId],
             [Amount], [CrDeAmount])
        VALUES
            (2, 0, 2, @SalTxId, @AccountId, @PayeeId, @COGSTotal, @CrDeAmount);

        -- Write sales journal rows
        INSERT INTO TransactionJournalDetail
            ([TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
             [Amount], [CrDeAmount], [SourceDetailId], [FactorToBase])
        SELECT
            [TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
            [Amount], [CrDeAmount], [SrcDetailId], [FactorToBase]
        FROM #SalTxDetail
        ORDER BY SortGroup, LineSort, RowSort, TxDetailId;

        -- Update sales header
        UPDATE Sales SET
            StageId = 4,
            ShipDate = @InvoiceDate,
            SubTotal = @SubTotal,
            TaxableTotal = @TaxableTotal,
            TaxTotal = @TaxTotal,
            SalesTotal = @SalesTotal,
            UpdatedAt = GETUTCDATE()
        WHERE SalesId = @SalesId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    -- Post-commit follow-up
    EXEC [Sales_CalcTotal] @SalesId;
    EXEC [Purchase_CalcTotalAndPercent] @PurchaseId, @PurFinalTotal OUTPUT
END
