SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 2026-08-08 DS-BILL-REFS: require and persist V-Doc#/CONT# before drop-ship Bill conversion.
CREATE   PROCEDURE [dbo].[DropShipment_ConvertPOToBill] -- EXEC dbo.DropShipment_ConvertPOToBill @PurchaseId=0,@EmpId=0,@VendorDocNumber='VDOC',@ContainerNumber='CONT'
    @PurchaseId INT,
    @EmpId INT,
    @VendorDocNumber NVARCHAR(100) = NULL,
    @ContainerNumber NVARCHAR(100) = NULL
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
    DECLARE @FinalVendorDocNumber NVARCHAR(100);
    DECLARE @FinalContainerNumber NVARCHAR(100);

    -- Purchase-side journal vars
    DECLARE @PurTxId BIGINT;
    DECLARE @PurDocOrder INT;
    DECLARE @PurDocType NVARCHAR(100) = 'Purchase';
    DECLARE @PurFinalTotal DECIMAL(18,2);
    DECLARE @PurItemFinalTotal DECIMAL(18,2);
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
    DECLARE @SalesTotalOut DECIMAL(18,2);

    DECLARE @InvoiceDate DATE;

    -- Resolve account IDs
    DECLARE @AcctTable AS TABLE (
        Id INT IDENTITY(1,1),
        AccountCode NVARCHAR(50),
        AccountId INT
    );
    INSERT INTO @AcctTable(AccountCode) VALUES('@AP');
    INSERT INTO @AcctTable(AccountCode) VALUES('@AR');
    INSERT INTO @AcctTable(AccountCode) VALUES('@FSTP');
    INSERT INTO @AcctTable(AccountCode) VALUES('@ISALE');
    INSERT INTO @AcctTable(AccountCode) VALUES('@ICREDIT');
    INSERT INTO @AcctTable(AccountCode) VALUES('@COGS');

    UPDATE t SET t.AccountId = a.AccountId
    FROM @AcctTable AS t
    INNER JOIN Account AS a ON t.AccountCode = a.AccountCode
                           AND ISNULL(a.Inactive, 0) = 0;

    -- Fail fast if any required posting account did not resolve -- missing or inactive.
    IF EXISTS (SELECT 1 FROM @AcctTable WHERE AccountId IS NULL)
        THROW 51001, 'Required posting account missing or inactive.', 1;

    -- Validate purchase
    SELECT
        @IsDropShip = IsDropShip,
        @PurchaseStageId = StageId,
        @SalesId = DropShipSalesId,
        @PurchaseNumber = PurchaseNumber,
        @VendorPayeeId = PayeeId,
        @InvoiceDate = ArrivalDate,
        @FinalVendorDocNumber = COALESCE(
            NULLIF(UPPER(LTRIM(RTRIM(@VendorDocNumber))), ''),
            NULLIF(UPPER(LTRIM(RTRIM(VendorDocNumber))), '')
        ),
        @FinalContainerNumber = COALESCE(
            NULLIF(UPPER(LTRIM(RTRIM(@ContainerNumber))), ''),
            NULLIF(UPPER(LTRIM(RTRIM(ContainerNumber))), '')
        )
    FROM Purchase
    WHERE PurchaseId = @PurchaseId;

    IF @IsDropShip = 0
    BEGIN
        RAISERROR('This is not a drop-ship purchase. Use the standard purchase workflow.', 16, 1);
        RETURN;
    END

    -- Slice 2B: drop-ship PO may be factory-progress stage 2 before customer receipt.
    -- Convert remains blocked once the PO leaves open pre-bill stages.
    IF @PurchaseStageId NOT IN (1, 2)
    BEGIN
        RAISERROR('Purchase is not in an open drop-ship PO stage. Cannot convert to bill.', 16, 1);
        RETURN;
    END

    IF @SalesId IS NULL
    BEGIN
        RAISERROR('Linked sales order not found on this drop-ship purchase.', 16, 1);
        RETURN;
    END

    -- Request values win; otherwise existing Purchase refs are reused. Both are
    -- required because these refs print on the drop-ship customer invoice.
    IF @FinalVendorDocNumber IS NULL
    BEGIN
        RAISERROR('V-Doc# is required before converting drop-ship PO to Bill.', 16, 1);
        RETURN;
    END

    IF @FinalContainerNumber IS NULL
    BEGIN
        RAISERROR('CONT# is required before converting drop-ship PO to Bill.', 16, 1);
        RETURN;
    END

    IF @InvoiceDate IS NULL
    BEGIN
        RAISERROR('Drop-ship purchase arrival date is required before converting to Bill.', 16, 1);
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

    -- 2026-07-21 DROPSHIP-RECEIPT-GUARD old guard allowed Order stage:
    -- IF @SalesStageId NOT IN (0, 3)
    -- BEGIN
    --     RAISERROR('Linked sales order is not in Order or Transit stage.', 16, 1);
    --     RETURN;
    -- END
    IF @SalesStageId <> 3
    BEGIN
        RAISERROR('Customer receipt must be confirmed before converting drop-ship PO to Bill.', 16, 1);
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

        -- 2026-07-21 DROPSHIP-RECEIPT-GUARD old Order-stage auto-fill path is no longer reachable:
        -- IF @SalesStageId = 0
        -- BEGIN
        --     UPDATE PurchaseDetail SET
        --         ShipQty = OrdQty0,
        --         BillQty = OrdQty0,
        --         ReceiveQty = OrdQty1,
        --         FinalQty = OrdQty1
        --     WHERE PurchaseId = @PurchaseId;
        -- END

        -- From received Sales stage: customer receipt must already be written by
        -- DropShipment_UpdateReceiptQty. Do not invent receipt qty from factory ShipQty
        -- or ordered qty; zero is valid, NULL is missing.
        -- UPDATE PurchaseDetail SET
        --     BillQty = COALESCE(BillQty, ShipQty, OrdQty0),
        --     ReceiveQty = COALESCE(ReceiveQty, FinalQty, ShipQty, OrdQty1),
        --     FinalQty = COALESCE(FinalQty, ReceiveQty, ShipQty, OrdQty1)
        -- WHERE PurchaseId = @PurchaseId;
        IF EXISTS
        (
            SELECT 1
            FROM PurchaseDetail
            WHERE PurchaseId = @PurchaseId
              AND LineType = 'I'
              AND ItemId IS NOT NULL
              AND (ReceiveQty IS NULL OR FinalQty IS NULL)
        )
        BEGIN
            RAISERROR('Customer receipt quantities must be confirmed before converting drop-ship PO to Bill.', 16, 1);
            RETURN;
        END

        -- 2026-07-05 (Phase B): PurchaseDetail base qty from ItemUnitId -> ItemUnit (Fn_QtyToBase),
        -- qty-only. Runs after customer receipt quantities are verified, before STEP 2 reads
        -- pd.BaseFinalQty. INNER JOIN = item lines only; account lines (no ItemUnitId) are posted
        -- to their own account below.
        UPDATE pd
        SET pd.BaseReceiveQty = dbo.Fn_QtyToBase(pd.ReceiveQty, iu.MultipleToBase, iu.FactorToBase),
            pd.BaseFinalQty   = dbo.Fn_QtyToBase(pd.FinalQty,   iu.MultipleToBase, iu.FactorToBase)
        FROM PurchaseDetail pd
        INNER JOIN ItemUnit iu ON iu.ItemUnitId = pd.ItemUnitId
        WHERE pd.PurchaseId = @PurchaseId;

        -- Persist ext totals before any posting/follow-up reads the detail rows.
        UPDATE pd
        SET BillExtTotal = ROUND(ISNULL(pd.BillQty, 0) * ISNULL(pd.BillPrice, 0), 2),
            FinalExtTotal = ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)
        FROM PurchaseDetail pd
        WHERE pd.PurchaseId = @PurchaseId;

        -- Calculate purchase totals from filled quantities. Item lines are product cost;
        -- account lines keep their account-aware sign so the AP header balances the staged rows.
        SELECT
            @PurBillTotal = ISNULL(SUM(
                CASE
                    WHEN pd.LineType = 'A' AND a.IsAccountDebit = 0
                        THEN -ROUND(ISNULL(pd.BillQty, 0) * ISNULL(pd.BillPrice, 0), 2)
                    ELSE ROUND(ISNULL(pd.BillQty, 0) * ISNULL(pd.BillPrice, 0), 2)
                END), 0),
            @PurFinalTotal = ISNULL(SUM(
                CASE
                    WHEN pd.LineType = 'A' AND a.IsAccountDebit = 0
                        THEN -ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)
                    ELSE ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)
                END), 0)
        FROM PurchaseDetail pd
        LEFT JOIN Account a ON a.AccountId = pd.AccountId
        WHERE pd.PurchaseId = @PurchaseId;

        SELECT @PurItemFinalTotal = ISNULL(SUM(ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)), 0)
        FROM PurchaseDetail pd
        WHERE pd.PurchaseId = @PurchaseId
          AND pd.LineType <> 'A'
          AND pd.ItemId IS NOT NULL;

        IF ABS(ISNULL(@PurItemFinalTotal, 0)) < 0.01
           AND EXISTS (
                SELECT 1
                FROM PurchaseDetail pd
                WHERE pd.PurchaseId = @PurchaseId
                  AND pd.LineType <> 'A'
                  AND pd.ItemId IS NOT NULL
                  AND ISNULL(pd.FinalQty, 0) <> 0
                  AND ISNULL(pd.FinalPrice, 0) <> 0
           )
            THROW 51002, 'Drop-ship product cost calculated to zero while received item qty and price are non-zero.', 1;

        -- ============================================================
        -- STEP 2: Purchase-side posting (DR @COGS, CR @AP)
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

        -- @COGS per item line. Drop-ship product cost goes straight to COGS;
        -- product @DSCC is no longer used for new drop-ship conversion.
        INSERT INTO #PurTxDetail
            ([SortLine], [RowSort], [TxId], [AccountId], [PayeeId], [ItemId],
             [Qty], [Price], [BillQty], [Amount], [CrDeAmount], [SrcDetailId], [FactorToBase])
        SELECT
            pd.PurchaseDetailId,
            1,
            @PurTxId,
            cogs.AccountId,
            @VendorPayeeId,
            pd.ItemId,
            pd.FinalQty,
            -- 4dp Slice-2: entered goods Price -> 4dp. was ROUND(pd.FinalPrice, 2)
            ROUND(pd.FinalPrice, 4),
            pd.BaseFinalQty,
            ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2),
            crde.CrDeAmount,
            pd.PurchaseDetailId,
            pd.FactorToBase
        FROM PurchaseDetail pd
        CROSS APPLY (SELECT AccountId FROM @AcctTable WHERE AccountCode = '@COGS') cogs
        CROSS APPLY dbo.Fn_CrDeAmount
		(
			CONVERT(NVARCHAR(20), cogs.AccountId),
			ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)
		) crde
        WHERE pd.PurchaseId = @PurchaseId
          AND pd.LineType <> 'A'
          AND pd.ItemId IS NOT NULL;

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
            -- was (pre 2026-07-14, WRONG - forced-ABS Amount and '-ABS' in BOTH CrDe branches):
            -- ABS(CASE WHEN a.IsAccountDebit = 1
            --     THEN ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)
            --     ELSE -ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)
            -- END),
            -- CASE WHEN a.IsAccountDebit = 1
            --     THEN -ABS(ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2))
            --     ELSE -ABS(ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2))
            -- END,
            -- 2026-07-14 PUR-AMT-SIGN: Amount = the SIGNED growth of the line account in its normal-balance
            --   direction (the original pre-ABS CASE: debit-nature -> +value, credit-nature -> -value);
            --   CrDeAmount = Fn_CrDeAmount(account, that same Amount) via CROSS APPLY, which resolves to a
            --   debit (-value) for the normal positive line on either nature - identical to old behavior.
            --   The old ABS() wrapper destroyed the credit-nature sign, and the old CrDe CASE ('-ABS' in both
            --   branches) was sign-blind: a negative line posted as a debit and UNBALANCED the journal.
            --   NOTE: since 2026-07-13 DROPSHIP-ITEMONLY the generated drop-ship PO carries item lines only,
            --   so this block fires only for legacy POs that still have 'A' lines.
            la.LineAmt,                 -- PUR_AMT_SIGN_20260714
            crdeA.CrDeAmount,
            pd.PurchaseDetailId
        FROM PurchaseDetail pd
        INNER JOIN Account a ON a.AccountId = pd.AccountId
        -- signed Amount computed ONCE (la.LineAmt); Fn_CrDeAmount consumes the SAME alias, and the SELECT above
        -- stores the SAME alias in Amount - one value, one derivation.
        CROSS APPLY (SELECT LineAmt =
            CASE WHEN a.IsAccountDebit = 1
                THEN ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)
                ELSE -ROUND(ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0), 2)
            END) la
        CROSS APPLY dbo.Fn_CrDeAmount(CONVERT(NVARCHAR(20), pd.AccountId), la.LineAmt) crdeA
        WHERE pd.PurchaseId = @PurchaseId
          AND pd.LineType = 'A';

        IF ABS((SELECT ISNULL(SUM(CrDeAmount), 0) FROM #PurTxDetail)) >= 0.01
            THROW 51003, 'Drop-ship purchase journal is not balanced before posting.', 1;

        -- Write purchase journal rows
        INSERT INTO TransactionJournalDetail
            ([TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
             [Amount], [CrDeAmount], [SourceDetailId], [FactorToBase])
        SELECT
            [TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
            [Amount], [CrDeAmount], [SrcDetailId], [FactorToBase]
        FROM #PurTxDetail
        ORDER BY SortLine, RowSort, TxDetailId;

        IF ABS((
            SELECT ISNULL(SUM(CrDeAmount), 0)
            FROM TransactionJournalDetail
            WHERE TxId = @PurTxId
        )) >= 0.01
            THROW 51004, 'Drop-ship purchase journal is not balanced after posting.', 1;

        -- Update purchase header
        UPDATE Purchase SET
            StageId = 6,
            ArrivalDate = @InvoiceDate,
            InvoiceDate = @InvoiceDate,
            VendorDocNumber = @FinalVendorDocNumber,
            ContainerNumber = @FinalContainerNumber,
            VendorTotal = @PurBillTotal,
            PurchaseTotal = @PurFinalTotal,
            UpdatedAt = GETUTCDATE()
        WHERE PurchaseId = @PurchaseId;

        -- ============================================================
        -- STEP 3: Sales-side posting (DR @AR, CR Revenue)
        -- ============================================================

        -- Fill SalesDetail quantities only for legacy NULLs before base refresh.
        -- Deliberate zero and partial receipt values must stay unchanged.
        IF EXISTS
        (
            SELECT 1
            FROM SalesDetail
            WHERE SalesId = @SalesId
              AND LineType = 'I'
              AND ItemId IS NOT NULL
              AND (ShipQty IS NULL OR BillQty IS NULL)
        )
        BEGIN
            RAISERROR('Customer receipt quantities must be confirmed on linked sales lines before converting drop-ship PO to Bill.', 16, 1);
            RETURN;
        END

        -- Slice 2B: conversion must not invent Sales receipt qty from order qty.
        -- Customer receipt is written by DropShipment_UpdateReceiptQty before conversion.
        -- UPDATE SalesDetail SET
        --     ShipQty = COALESCE(ShipQty, BillQty, OrdQty),
        --     BillQty = COALESCE(BillQty, ShipQty, OrdQty)
        -- WHERE SalesId = @SalesId
        --   AND (ShipQty IS NULL OR BillQty IS NULL);

        -- Recalculate sales totals from SalesDetail after legacy null-fill.
        SELECT @SubTotal = ISNULL(SUM(ROUND(ISNULL(BillQty, 0) * ISNULL(UnitPrice, 0), 2)), 0)
        FROM SalesDetail WHERE SalesId = @SalesId;

        SELECT @TaxableTotal = ISNULL(SUM(ROUND(ISNULL(BillQty, 0) * ISNULL(UnitPrice, 0), 2)), 0)
        FROM SalesDetail WHERE SalesId = @SalesId AND IsTaxable = 1;

        SET @TaxTotal = ROUND(@TaxableTotal * ISNULL(@TaxRate, 0), 2);
        SET @SalesTotal = @SubTotal + @TaxTotal;

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
            (@InvoiceDate, GETUTCDATE(), @SalDocOrder, @SalDocType, @SalesNumber);

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

        IF ABS((SELECT ISNULL(SUM(CrDeAmount), 0) FROM #SalTxDetail)) >= 0.01
            THROW 51005, 'Drop-ship sales journal is not balanced before posting.', 1;

        -- Write sales journal rows
        INSERT INTO TransactionJournalDetail
            ([TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
             [Amount], [CrDeAmount], [SourceDetailId], [FactorToBase])
        SELECT
            [TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
            [Amount], [CrDeAmount], [SrcDetailId], [FactorToBase]
        FROM #SalTxDetail
        ORDER BY SortGroup, LineSort, RowSort, TxDetailId;

        IF ABS((
            SELECT ISNULL(SUM(CrDeAmount), 0)
            FROM TransactionJournalDetail
            WHERE TxId = @SalTxId
        )) >= 0.01
            THROW 51006, 'Drop-ship sales journal is not balanced after posting.', 1;

        -- Update sales header
        UPDATE Sales SET
            -- 2026-08-06 DS-STAGE-MINIMAL: PO-to-Bill conversion keeps DS Sales at StageId 3.
            -- StageId = 4,
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

GO
