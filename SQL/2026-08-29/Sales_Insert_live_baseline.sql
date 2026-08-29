
-- FIX_ICREDIT_AMOUNT_SIGN + FIX_ACCTLINE_AMOUNT_SIGN 2026-07-16: journal rows follow the model
-- (Amount = account inc/dec, set FIRST; then CrDeAmount = Fn_CrDeAmount(Amount)).
--   - Item revenue rows (@ISALE/@ICREDIT): the value's sign chooses the account, so Amount =
--     magnitude (ABS of BillQty*UnitPrice). 2 spots: NonInventory + Inventory revenue rows.
--   - Account-line rows (LineType='A'): fixed user account per row + document-signed value, so
--     Amount = account inc/dec (flip for debit-normal accounts via the CASE), CrDeAmount derived
--     from it. CrDeAmount is UNCHANGED (= the entered value, the balancing amount); only Amount
--     becomes the inc/dec. 1 spot: the account-line insert block.
-- See baseline: KLS/SQL/2026-07-16/Sales_Insert_live_baseline.sql


CREATE   PROCEDURE [dbo].[Sales_Insert]
    @SalesId INT,
    @PayeeId INT,
    @ShipDate DATE,
    @ShipRoute NVARCHAR(10),
    @Instruction NVARCHAR(300) = 'Web',
    @StageId INT,
    @EmpId INT,
    @NewSalesId INT OUTPUT,
    @DocType CHAR(2) = 'SO',
    @ParentSalesNumber INT = NULL,
    @AllowNoParentOverride BIT = 0
AS
BEGIN
    -- Section 1: initialize procedure state and working variables.
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @TermId INT;
    DECLARE @SalesNumber INT;
    DECLARE @SalesDate DATETIME = GETUTCDATE();
    DECLARE @BillId INT;
    DECLARE @TaxRate DECIMAL(18,4);
    DECLARE @RCExpireDate DATE;
    DECLARE @SalesRepId INT;
    DECLARE @IsCreditHold BIT;
    DECLARE @IsStatementPrint BIT;
    DECLARE @ShippingCarrierId INT;
    DECLARE @SubTotal DECIMAL(18,2);
    DECLARE @TaxableTotal DECIMAL(18,2);
    DECLARE @SalesTotal DECIMAL(18,2);
    DECLARE @TaxTotal DECIMAL(18,2);

    DECLARE @TxId BIGINT;
    DECLARE @CrDeAmount DECIMAL(18,2) = 0;
    DECLARE @AccountId INT;
    DECLARE @DocOrder INT;
    DECLARE @JournalDocType NVARCHAR(100);
    DECLARE @LockResult INT;
    DECLARE @LockResource NVARCHAR(200);
    DECLARE @SalesDocNumber NVARCHAR(50);

    -- Section 2: validate document-type-specific business rules before posting.
    IF @DocType = 'SO'
    BEGIN
        SET @ParentSalesNumber = NULL;
        SET @JournalDocType = 'Sales';
    END
    ELSE IF @DocType = 'CM'
    BEGIN
        SET @JournalDocType = 'Sales Credit Memo';

        IF @ParentSalesNumber IS NULL AND ISNULL(@AllowNoParentOverride, 0) = 0
        BEGIN
            RAISERROR('Credit memo without parent requires manager override.', 16, 1);
            RETURN;
        END

        IF EXISTS
        (
            SELECT 1
            FROM TempSales
            WHERE EmpId = @EmpId
              AND PayeeId = @PayeeId
              AND SalesId = 0
              AND IsStrike = 0
              AND (
                    (@ParentSalesNumber IS NULL AND ParentSalesNumber IS NULL)
                    OR (ParentSalesNumber = @ParentSalesNumber)
                  )
              AND ISNULL(ExtTotal, ROUND(ISNULL(BillQty, 0) * ISNULL(UnitPrice, 0), 2)) >= 0
        )
        BEGIN
            RAISERROR('Credit memo lines must have negative totals.', 16, 1);
            RETURN;
        END

        IF EXISTS
        (
            SELECT 1
            FROM TempSales
            WHERE EmpId = @EmpId
              AND PayeeId = @PayeeId
              AND SalesId = 0
              AND IsStrike = 0
              AND (
                    (@ParentSalesNumber IS NULL AND ParentSalesNumber IS NULL)
                    OR (ParentSalesNumber = @ParentSalesNumber)
                  )
              AND LineType <> 'I'
        )
        BEGIN
            RAISERROR('Credit memo only supports item lines.', 16, 1);
            RETURN;
        END
    END
    ELSE IF @DocType = 'DM'
    BEGIN
        SET @JournalDocType = 'Sales Debit Memo';
    END
    ELSE
    BEGIN
        RAISERROR('Invalid document type.', 16, 1);
        RETURN;
    END

    -- Section 3: confirm this checkout group still has live temp-cart rows.
    IF NOT EXISTS
    (
        SELECT 1
        FROM TempSales
        WHERE EmpId = @EmpId
          AND PayeeId = @PayeeId
          AND SalesId = 0
          AND IsStrike = 0
          AND (
                (@DocType = 'SO')
                OR (@ParentSalesNumber IS NULL AND ParentSalesNumber IS NULL)
                OR (ParentSalesNumber = @ParentSalesNumber)
              )
    )
    BEGIN
        RAISERROR('No temp sales rows found for this checkout group.', 16, 1);
        RETURN;
    END

    -- Section 4: resolve lookup/config data used by the posting transaction.
    SET @LockResource =
        'Sales_Insert_'
        + CONVERT(NVARCHAR(20), @EmpId) + '_'
        + CONVERT(NVARCHAR(20), @PayeeId) + '_'
        + ISNULL(@DocType, 'SO') + '_'
        + ISNULL(CONVERT(NVARCHAR(20), @ParentSalesNumber), 'NULL');

    EXEC [Get_SourceDocOrder] @JournalDocType, @DocOrder OUTPUT;

    DECLARE @AcctTable AS TABLE
    (
        Id INT IDENTITY(1,1),
        AccountCode NVARCHAR(50),
        AccountId INT
    );

    INSERT INTO @AcctTable (AccountCode) VALUES ('@AR');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@FSTP');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@ICREDIT');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@ISALE');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@COGS');
    INSERT INTO @AcctTable (AccountCode) VALUES ('@INV');

    UPDATE t
    SET t.AccountId = a.AccountId
    FROM @AcctTable AS t
    INNER JOIN Account AS a ON t.AccountCode = a.AccountCode;

    SELECT
        @TermId = TermId,
        @BillId = ISNULL(BillId, p.PayeeId),
        @TaxRate = TaxRate,
        @RCExpireDate = RCExpireDate,
        @SalesRepId = ISNULL(SalesRepId, @EmpId),
        @IsCreditHold = IsCreditHold,
        @ShippingCarrierId = ShippingCarrierId,
        @IsStatementPrint = IsStatementPrint
    FROM Payee AS p
    INNER JOIN Customer AS c ON p.PayeeId = c.PayeeId
    WHERE p.PayeeId = @PayeeId;

    IF @SalesId > 0
        SET @SalesNumber = @SalesId;
    ELSE
        SET @SalesNumber = NEXT VALUE FOR dbo.Seq_SalesNumber;

    IF @ShipDate IS NULL
        EXEC dbo.Fn_Calc_NextShipDate @PayeeId, @ShipDate OUTPUT;

    IF @ShipRoute = 'CM'
        EXEC [Get_TodayLocalDate] @ShipDate OUTPUT;

    BEGIN TRY
        -- Section 5: start the protected posting transaction.
        BEGIN TRANSACTION;

        EXEC @LockResult = sp_getapplock
            @Resource = @LockResource,
            @LockMode = 'Exclusive',
            @LockOwner = 'Transaction',
            @LockTimeout = 0;

        IF @LockResult < 0
        BEGIN
            RAISERROR('This checkout group is already being posted.', 16, 1);
        END

        EXEC dbo.SalesDocNumber_Generate
            @DocType = @DocType,
            @SalesDocNumber = @SalesDocNumber OUTPUT;

        -- Section 6: create the Sales header.
        INSERT INTO [dbo].[Sales]
        (
            [SalesNumber], [StageId], [SalesDate], [ShipDate], [ShipRoute],
            [ShipId], [BillId], [SalesRepId], [TermId],
            [SubTotal], [TaxableTotal], [TaxPercent], [TaxTotal], [SalesTotal], [AmountDue],
            [Instruction], [ShippingCarrierId], [IsLoadSeparate], [IsLocked],
            [IsStatementAttached], [Enterby], [CreatedAt],
            [ParentSalesNumber], [DocType], [SalesDocNumber]
        )
        VALUES
        (
            @SalesNumber, @StageId, @SalesDate, @ShipDate, @ShipRoute,
            @PayeeId, @BillId, @SalesRepId, @TermId,
            0, 0, @TaxRate, 0, 0, 0,
            @Instruction, @ShippingCarrierId, 0, 0,
            @IsStatementPrint, @EmpId, @SalesDate,
            @ParentSalesNumber, @DocType, @SalesDocNumber
        );

        SET @SalesId = SCOPE_IDENTITY();

        -- Section 7: insert SalesDetail from TempSales and capture TempSalesId ->
        -- SalesDetailId mapping so parent/root links can be restored afterward.
        DECLARE @IdMap TABLE
        (
            TempSalesId INT,
            SalesDetailId INT,
            ParentTempSalesId INT,
            RootTempSalesId INT
        );

        -- Keep MERGE here because SQL Server allows source.* in MERGE OUTPUT,
        -- which we need for TempSalesId -> SalesDetailId mapping.
        -- TempSales.LineId is now the canonical cart order. The TempSales resequence
        -- trigger already keeps owner/reward groups in the right shape, so Sales_Insert
        -- should trust TempSales.LineId instead of rebuilding line order here.
        MERGE INTO [dbo].[SalesDetail] AS target
        USING
        (
            SELECT
                TempSalesId,
                ParentTempSalesId,
                RootTempSalesId,
                LineId,
                LineType,
                ItemId,
                AccountId,
                ItemUnitId,
                Unit,
                OrdQty,
                ShipQty,
                BillQty,
                UnitPrice,
                ROUND(BillQty * UnitPrice, 2) AS ExtTotal,
                Notes,
                CASE
                    WHEN LineType = 'A' THEN 0
                    ELSE (SELECT IsTaxable FROM dbo.Fn_IsItemTaxable(ItemId, @ShipDate, @PayeeId))
                END AS IsTaxable,
                OrgPrice,
                DiscountPercent,
                FactorToBase,
                CartLineType,
                IsSystemManaged,
                DisplaySort
            FROM TempSales
            WHERE EmpId = @EmpId
              AND PayeeId = @PayeeId
              AND SalesId = 0
              AND IsStrike = 0
              AND (
                    (@DocType = 'SO')
                    OR (@ParentSalesNumber IS NULL AND ParentSalesNumber IS NULL)
                    OR (ParentSalesNumber = @ParentSalesNumber)
                  )
        ) AS source
        ON 1 = 0
        WHEN NOT MATCHED THEN
            INSERT
            (
                [SalesId], [LineId], [LineType], [ItemId], [AccountId],
                [ItemUnitId], [Unit], [OrdQty], [ShipQty], [BillQty],
                [UnitPrice], [ExtTotal], [Notes], [IsTaxable],
                [OrgPrice], [DiscountPercent], [FactorToBase],
                [ParentSalesDetailId], [RootSalesDetailId],
                [CartLineType], [IsSystemManaged], [DisplaySort]
            )
            VALUES
            (
                @SalesId, source.LineId, source.LineType, source.ItemId, source.AccountId,
                source.ItemUnitId, source.Unit, source.OrdQty, source.ShipQty, source.BillQty,
                source.UnitPrice, source.ExtTotal, source.Notes, source.IsTaxable,
                source.OrgPrice, source.DiscountPercent, source.FactorToBase,
                NULL, NULL,
                source.CartLineType, source.IsSystemManaged, source.DisplaySort
            )
        OUTPUT
            source.TempSalesId,
            inserted.SalesDetailId,
            source.ParentTempSalesId,
            source.RootTempSalesId
        INTO @IdMap (TempSalesId, SalesDetailId, ParentTempSalesId, RootTempSalesId);

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('No detail rows inserted - TempSales may have been cleared by another session.', 16, 1);
        END

        -- Section 8: restore parent/root detail relationships after the insert.
        UPDATE sd
        SET
            sd.ParentSalesDetailId = pmap.SalesDetailId,
            sd.RootSalesDetailId = ISNULL(rmap.SalesDetailId, pmap.SalesDetailId)
        FROM SalesDetail sd
        INNER JOIN @IdMap m ON m.SalesDetailId = sd.SalesDetailId
        LEFT JOIN @IdMap pmap ON pmap.TempSalesId = m.ParentTempSalesId
        LEFT JOIN @IdMap rmap ON rmap.TempSalesId = m.RootTempSalesId
        WHERE m.ParentTempSalesId IS NOT NULL;

        -- Section 9: refresh base quantities inside the transaction.
        -- Sales_CalcTotal now runs after commit, but @INV journal rows still
        -- need current base quantities here before journal build.
        -- 2026-07-04 (Phase B): base qty derives from the line's ItemUnitId -> ItemUnit
        -- (single source of truth): BaseQty = qty * MultipleToBase / FactorToBase via
        -- dbo.Fn_QtyToBase (inlined). Immutable ratios => the join is authoritative, so the
        -- sd.FactorToBase snapshot read is retired here. INNER JOIN = item lines only; account
        -- lines (LineType='A', no ItemUnitId) keep base qty NULL (they feed no @INV row).
        -- Identity today (all MultipleToBase=1 => qty/factor). Prior block:
        -- UPDATE SalesDetail
        -- SET
        --     BaseOrdQty  = ROUND(OrdQty  / NULLIF(FactorToBase, 0), 6),
        --     BaseShipQty = ROUND(ShipQty / NULLIF(FactorToBase, 0), 6),
        --     BaseBillQty = ROUND(BillQty / NULLIF(FactorToBase, 0), 6)
        -- WHERE SalesId = @SalesId
        UPDATE sd
        SET
            sd.BaseOrdQty  = dbo.Fn_QtyToBase(sd.OrdQty,  iu.MultipleToBase, iu.FactorToBase),
            sd.BaseShipQty = dbo.Fn_QtyToBase(sd.ShipQty, iu.MultipleToBase, iu.FactorToBase),
            sd.BaseBillQty = dbo.Fn_QtyToBase(sd.BillQty, iu.MultipleToBase, iu.FactorToBase)
        FROM SalesDetail sd
        INNER JOIN ItemUnit iu ON iu.ItemUnitId = sd.ItemUnitId
        WHERE sd.SalesId = @SalesId

        -- Section 10: calculate the 4 journal-driving header totals inline.
        -- Keep only the core totals needed for Sales and @AR/@FSTP journal rows.
        SELECT @SubTotal = ISNULL(SUM(ROUND(BillQty * UnitPrice, 2)), 0)
        FROM SalesDetail
        WHERE SalesId = @SalesId;

        SELECT @TaxableTotal = ISNULL(SUM(ROUND(BillQty * UnitPrice, 2)), 0)
        FROM SalesDetail
        WHERE SalesId = @SalesId
          AND IsTaxable = 1;

        SET @TaxTotal = ROUND(@TaxableTotal * @TaxRate, 2);
        SET @SalesTotal = @SubTotal + @TaxTotal;

        UPDATE Sales
        SET
            SubTotal = @SubTotal,
            TaxableTotal = @TaxableTotal,
            TaxTotal = @TaxTotal,
            SalesTotal = @SalesTotal
        WHERE SalesId = @SalesId;

        -- Section 11: stage journal rows in a temp table so the final insert can
        -- stay ordered while the build itself remains set-based.
        CREATE TABLE #SalTxDetail
        (
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

        -- Section 12: create the TransactionJournal header and seed header rows
        -- such as @AR and optional tax payable.
        INSERT INTO [dbo].[TransactionJournal]
        (
            [TxDate], [TxTime], [SourceDocOrder], [SourceDocType], [SourceDocNumber]
        )
        VALUES
        (
            @ShipDate, GETUTCDATE(), @DocOrder, @JournalDocType, @SalesNumber
        );

        SET @TxId = SCOPE_IDENTITY();

        SELECT @AccountId = AccountId
        FROM @AcctTable
        WHERE AccountCode = '@AR';

        EXEC Fn_Adjust_CrDeAmount @AccountId, @SalesTotal, @CrDeAmount OUTPUT;

        INSERT INTO #SalTxDetail
            ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [PayeeId], [Amount], [CrDeAmount])
        VALUES
            (0, 0, 1, @TxId, @AccountId, @PayeeId, @SalesTotal, @CrDeAmount);

        IF @TaxTotal <> 0
        BEGIN
            SELECT @AccountId = AccountId
            FROM @AcctTable
            WHERE AccountCode = '@FSTP';

            EXEC Fn_Adjust_CrDeAmount @AccountId, @TaxTotal, @CrDeAmount OUTPUT;

            INSERT INTO #SalTxDetail
                ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [Amount], [CrDeAmount])
            VALUES
                (0, 0, 2, @TxId, @AccountId, @TaxTotal, @CrDeAmount);
        END

        -- Section 13: build line-level journal rows set-based.
        -- Original Sales_Insert emitted journal rows per SalesDetail line.
        -- One source line can map to multiple journal rows, and those rows must
        -- stay together. The baseline row shapes are:
        --   A line            -> account row only
        --   NonInventory line -> sales row only
        --   Inventory line    -> sales row, then @COGS, then @INV
        -- The set-based build therefore uses explicit sort keys:
        --   SortGroup = header rows first, detail rows second
        --   LineSort  = SalesDetail.LineId (preserve source-line order)
        --   RowSort   = row order within one source line
        --               1 = sales/account row
        --               2 = @COGS
        --               3 = @INV
        -- This preserves the original per-line grouping and keeps @COGS
        -- immediately before @INV, which RecalcQAV still expects.
        INSERT INTO #SalTxDetail
            ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [PayeeId], [Qty], [Price], [BillQty], [Amount], [CrDeAmount], [SrcDetailId])
        SELECT
            1,
            sd.LineId,
            1,
            @TxId,
            sd.AccountId,
            @PayeeId,
            sd.BillQty,
            sd.UnitPrice,
            ROUND(sd.BillQty * sd.UnitPrice, 2),   -- [BillQty]
            -- 2026-07-16 FIX_ACCTLINE_AMOUNT_SIGN: honor the model -- set [Amount] (the account's
            -- inc/dec) first, then DERIVE [CrDeAmount] = Fn_CrDeAmount(Amount). The account-line's
            -- ExtTotal is stored sale-signed (a discount is negative because it reduces the sale),
            -- so for a debit-normal contra account (e.g. @IDG "Discount Given", which a discount
            -- INCREASES) we flip it to the account's inc/dec; credit-normal (income) needs no flip.
            -- amt.AcctAmount is that inc/dec; Fn_CrDeAmount then owns the single debit/credit rule.
            -- OLD: [Amount] and [CrDeAmount] were both ROUND(sd.BillQty * sd.UnitPrice, 2)
            --      (CrDeAmount was never normalized through Fn_CrDeAmount).
            amt.AcctAmount,     -- [Amount] = account inc/dec (non-CPA confirmable)
            crde.CrDeAmount,    -- [CrDeAmount] = Fn_CrDeAmount(Amount)
            sd.SalesDetailId
        FROM SalesDetail sd
        INNER JOIN dbo.Account a ON a.AccountId = sd.AccountId
        CROSS APPLY
        (
            SELECT AcctAmount = CASE WHEN a.IsAccountDebit = 1
                                     THEN -ROUND(sd.BillQty * sd.UnitPrice, 2)
                                     ELSE  ROUND(sd.BillQty * sd.UnitPrice, 2) END
        ) amt
        CROSS APPLY dbo.Fn_CrDeAmount(sd.AccountId, amt.AcctAmount) crde
        WHERE sd.SalesId = @SalesId
          AND sd.LineType = 'A';

        INSERT INTO #SalTxDetail
            ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
             [Amount], [CrDeAmount], [SrcDetailId], [FactorToBase])
        SELECT
            1,
            sd.LineId,
            1,
            @TxId,
            acct.AccountId,
            @PayeeId,
            sd.ItemId,
            sd.BillQty,
            sd.UnitPrice,
            ROUND(sd.BillQty * sd.UnitPrice, 2),
            -- 2026-07-16 FIX_ICREDIT_AMOUNT_SIGN: [Amount] must be the account-value MAGNITUDE,
            -- the same ABS(...) base fed to Fn_CrDeAmount below, so credit-memo @ICREDIT rows
            -- store +value (was storing the signed -value while CrDeAmount from ABS was correct).
            -- OLD: ROUND(sd.BillQty * sd.UnitPrice, 2),
            ABS(ROUND(sd.BillQty * sd.UnitPrice, 2)),
            crde.CrDeAmount,
            sd.SalesDetailId,
            sd.FactorToBase
        FROM SalesDetail sd
        CROSS APPLY
        (
            SELECT AccountId
            FROM @AcctTable
            WHERE AccountCode = CASE
                WHEN ROUND(sd.BillQty * sd.UnitPrice, 2) < 0 THEN '@ICREDIT'
                ELSE '@ISALE'
            END
        ) acct
        CROSS APPLY dbo.Fn_CrDeAmount
        (
            acct.AccountId,
            ABS(ROUND(sd.BillQty * sd.UnitPrice, 2))
        ) crde
        INNER JOIN Item i ON sd.ItemId = i.ItemId
        WHERE sd.SalesId = @SalesId
          AND sd.LineType <> 'A'
          AND i.ItemType = 'NonInventory';

        INSERT INTO #SalTxDetail
            ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
             [Amount], [CrDeAmount], [SrcDetailId], [FactorToBase])
        SELECT
            1,
            sd.LineId,
            1,
            @TxId,
            acct.AccountId,
            @PayeeId,
            sd.ItemId,
            sd.BillQty,
            sd.UnitPrice,
            ROUND(sd.BillQty * sd.UnitPrice, 2),
            -- 2026-07-16 FIX_ICREDIT_AMOUNT_SIGN: [Amount] must be the account-value MAGNITUDE,
            -- the same ABS(...) base fed to Fn_CrDeAmount below, so credit-memo @ICREDIT rows
            -- store +value (was storing the signed -value while CrDeAmount from ABS was correct).
            -- OLD: ROUND(sd.BillQty * sd.UnitPrice, 2),
            ABS(ROUND(sd.BillQty * sd.UnitPrice, 2)),
            crde.CrDeAmount,
            sd.SalesDetailId,
            sd.FactorToBase
        FROM SalesDetail sd
        CROSS APPLY
        (
            SELECT AccountId
            FROM @AcctTable
            WHERE AccountCode = CASE
                WHEN ROUND(sd.BillQty * sd.UnitPrice, 2) < 0 THEN '@ICREDIT'
                ELSE '@ISALE'
            END
        ) acct
        CROSS APPLY dbo.Fn_CrDeAmount
        (
            acct.AccountId,
            ABS(ROUND(sd.BillQty * sd.UnitPrice, 2))
        ) crde
        INNER JOIN Item i ON sd.ItemId = i.ItemId
        WHERE sd.SalesId = @SalesId
          AND sd.LineType <> 'A'
          AND i.ItemType <> 'NonInventory';

        INSERT INTO #SalTxDetail
            ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [PayeeId], [ItemId], [FactorToBase], [SrcDetailId])
        SELECT
            1,
            sd.LineId,
            2,
            @TxId,
            (SELECT AccountId FROM @AcctTable WHERE AccountCode = '@COGS'),
            @PayeeId,
            sd.ItemId,
            sd.FactorToBase,
            sd.SalesDetailId
        FROM SalesDetail sd
        INNER JOIN Item i ON sd.ItemId = i.ItemId
        WHERE sd.SalesId = @SalesId
          AND sd.LineType <> 'A'
          AND i.ItemType <> 'NonInventory';

        INSERT INTO #SalTxDetail
            ([SortGroup], [LineSort], [RowSort], [TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
             [SrcDetailId], [FactorToBase])
        SELECT
            1,
            sd.LineId,
            3,
            @TxId,
            (SELECT AccountId FROM @AcctTable WHERE AccountCode = '@INV'),
            @PayeeId,
            sd.ItemId,
            sd.BaseShipQty,                 -- Qty: base physical (unchanged)
            sd.UnitPrice,                   -- Price: entered revenue (unchanged; no landed on sales)
            -- 2026-07-07 Effort-B Sales_Insert: @INV BillQty base->entered (audit-consistency; RecalcQAV values
            -- sales as Qty*AvgCost, never reads @INV BillQty -> zero costing impact).
            -- OLD: sd.BaseBillQty,
            sd.BillQty,                     -- BillQty: entered value
            sd.SalesDetailId,
            -- 2026-07-07 Effort-B Sales_Insert: FactorToBase slot ratio->EntQty (ShipQty). Audit-only, no consumer.
            -- OLD: sd.FactorToBase
            sd.ShipQty                      -- FactorToBase slot: entered physical qty (audit)
        FROM SalesDetail sd
        INNER JOIN Item i ON sd.ItemId = i.ItemId
        WHERE sd.SalesId = @SalesId
          AND sd.LineType <> 'A'
          AND i.ItemType <> 'NonInventory';

        -- Section 14: write staged journal rows to TransactionJournalDetail in the
        -- preserved baseline order.
        INSERT INTO TransactionJournalDetail
        (
            [TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
            [Amount], [CrDeAmount], [SourceDetailId], [FactorToBase]
        )
        SELECT
            [TxId], [AccountId], [PayeeId], [ItemId], [Qty], [Price], [BillQty],
            [Amount], [CrDeAmount], [SrcDetailId], [FactorToBase]
        FROM #SalTxDetail
        -- SortGroup keeps header rows first; LineSort/RowSort preserve original
        -- per-line journal row grouping and inventory pair adjacency.
        ORDER BY SortGroup, LineSort, RowSort, TxDetailId;

        -- Section 15: clear temp-cart rows only after durable Sales/SalesDetail and
        -- journal rows have been written successfully.
        DELETE tsp
        FROM TempSalesPromo tsp
        WHERE EXISTS
        (
            SELECT 1
            FROM @IdMap m
            WHERE m.TempSalesId = tsp.OwnerTempSalesId
               OR m.TempSalesId = tsp.PromoTempSalesId
        );

        DELETE ts
        FROM TempSales ts
        INNER JOIN @IdMap m ON m.TempSalesId = ts.TempSalesId;

        SET @NewSalesId = @SalesId;

        -- Section 16: enqueue inventory recalculation before commit completes.
        EXEC Recalc_AfterInsert @TxId, @ShipDate;

        COMMIT TRANSACTION;

        -- Section 17: run broader/non-core follow-up recalculation after commit.
        -- Original flow did all recalculation work before commit. We now move
        -- Sales_CalcTotal outside the transaction because the core totals are
        -- already persisted above. This keeps AmountDue/due-date/aging/base-qty/
        -- FIFO/margin follow-up work out of the lock-heavy posting section.
        EXEC [Sales_CalcTotal] @SalesId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    -- End Summary:
    --   1. TempSales.LineId is the canonical cart order and is persisted directly.
    --   2. Base qty is refreshed here before journal build because @INV rows need it.
    --   3. Only the 4 journal-driving header totals stay inside the transaction.
    --   4. TransactionJournalDetail rows are built set-based, but emitted in
    --      preserved per-line baseline order.
    --   5. Sales_CalcTotal remains post-commit follow-up for non-core work.
END




