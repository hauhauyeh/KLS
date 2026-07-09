
CREATE   PROCEDURE [dbo].[RecalcQAV] --EXEC [RecalcQAV] 419,'02/25/26'
    @ItemId INT,
    @BeginDate DATE,
    @LCloQty DECIMAL(18,6) OUTPUT,
    @LAvgCost DECIMAL(18,6) OUTPUT,
    @LInventoryValue DECIMAL(18,6) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @InvAccountId INT
    DECLARE @COGSAccountId INT
    DECLARE @InvGainAccountId INT
    DECLARE @InvLossAccountId INT
    DECLARE @AREAccountId INT

    SELECT
        @InvAccountId     = MAX(CASE WHEN AccountCode = '@INV'   THEN AccountId END),
        @COGSAccountId    = MAX(CASE WHEN AccountCode = '@COGS'  THEN AccountId END),
        @InvGainAccountId = MAX(CASE WHEN AccountCode = '@IINVG' THEN AccountId END),
        @InvLossAccountId = MAX(CASE WHEN AccountCode = '@EINVL' THEN AccountId END),
        @AREAccountId     = MAX(CASE WHEN AccountCode = '@ARE'   THEN AccountId END)
    FROM dbo.Account
    WHERE AccountCode IN ('@INV', '@COGS', '@IINVG', '@EINVL', '@ARE');

    -- 1. Get Last Date (before BeginDate)
    DECLARE @LastDate DATE;

    SELECT @LastDate = MAX(tj.TxDate)
    FROM dbo.TransactionJournal tj
    INNER JOIN dbo.TransactionJournalDetail tjd ON tj.TxId = tjd.TxId
    WHERE tj.TxDate < @BeginDate
        AND tjd.AccountId = @InvAccountId
        AND tjd.ItemId = @ItemId;

    -- 2. Index/re-sort relevant transactions into a temp table
    CREATE TABLE #QAVTable
    (
        AutoId INT IDENTITY(1,1) PRIMARY KEY,
        TxDate DATE,
        SourceDocOrder INT,
        TxDetailId BIGINT,
        SourceDocNum INT,
        Qty DECIMAL(18,6),
        Price DECIMAL(18,6),
        BillQty DECIMAL(18,6),
        PayeeId INT,
        FactorToBase DECIMAL(18,6),
        PairedAccountId INT
    );

    -- Preload the loop-driving row data once so the RBAR section does not
    -- re-query TransactionJournalDetail for every inventory row.
    INSERT INTO #QAVTable
    (
        TxDate,
        SourceDocOrder,
        TxDetailId,
        SourceDocNum,
        Qty,
        Price,
        BillQty,
        PayeeId,
        FactorToBase,
        PairedAccountId
    )
    SELECT
        tj.TxDate,
        tj.SourceDocOrder,
        tjd.TxDetailId,
        tj.SourceDocNumber,
        tjd.Qty,
        tjd.Price,
        tjd.BillQty,
        tjd.PayeeId,
        ISNULL(tjd.FactorToBase,1),
        paired.AccountId
    FROM dbo.TransactionJournal AS tj
    INNER JOIN dbo.TransactionJournalDetail AS tjd ON tj.TxId = tjd.TxId
    LEFT JOIN dbo.TransactionJournalDetail AS paired ON paired.TxDetailId = tjd.TxDetailId - 1
    WHERE
        (tj.TxDate >= ISNULL(@LastDate,@BeginDate)) and
        --IF @LastDate IS NULL SET @LastDate = @BeginDate
        (tjd.AccountId = @InvAccountId) and
        (tjd.ItemId = @ItemId)
    ORDER BY tj.TxDate, tj.SourceDocOrder, tjd.TxDetailId

    -- 3. Get Item Retail Factor (set to 1 if not found or zero)
    --DECLARE @RetailFactor MONEY = 1;
    --SELECT @RetailFactor = CASE WHEN RetailFactor = 0 THEN 1 ELSE RetailFactor END
    --FROM Item
    --WHERE ItemCode = @ItemId;

    -- 4. Set initial values
    SET @LCloQty = 0;
    SET @LAvgCost = 0;
    SET @LInventoryValue = 0;

    DECLARE @LastDateMaxId INT, @TxDetailId INT;

    IF @LastDate IS NOT NULL
    BEGIN
        SELECT @LastDateMaxId = MAX(AutoId)
        FROM #QAVTable
        WHERE TxDate = @LastDate;

        SELECT @TxDetailId = TxDetailId
        FROM #QAVTable
        WHERE AutoId = @LastDateMaxId;

        SELECT
            @LCloQty = ISNULL(ClosingQty, 0),
            @LAvgCost = ISNULL(AverageCost, 0),
            @LInventoryValue = ISNULL(InventoryValue, 0)
        FROM TransactionJournalDetail
        WHERE TxDetailId = @TxDetailId;
    END

    -- 5. Set up loop variables for row-by-row processing
    DECLARE @RowNum INT = 1, @MaxRow INT, @NextTxDate DATE;

    SELECT @MaxRow = COUNT(*)
    FROM #QAVTable;

    IF @MaxRow = 0 RETURN;

    -- 6. Find the first transaction to start processing
    -- Find the earliest transaction date on or after @BeginDate in the temp table
    -- Find the AutoId (row number) of the first transaction on that date (this will be the starting point for the loop)
    SELECT @NextTxDate = MIN(TxDate)
    FROM #QAVTable
    WHERE TxDate >= @BeginDate

    SELECT @RowNum = MIN(AutoId)
    FROM #QAVTable
    WHERE TxDate = @NextTxDate

    /*
        start to recalclating
    */
    DECLARE
        @MyId INT,
        @MyTxDate DATE,
        @MySourceDocOrder INT,
        @MyTxDetailId BIGINT,
        @MySourceDocNum INT,

        @Qty DECIMAL(18,6),
        @Price DECIMAL(18,6),
        @BillQty DECIMAL(18,6),
        @FactorToBase DECIMAL(18,6),
        @CloQty DECIMAL(18,6),
        @AvgCost DECIMAL(18,6),
        @InventoryValue DECIMAL(18,6),
        @COGSAdjAmount DECIMAL(18,6),
        @RoundingError DECIMAL(18,6),
        @DiffInventoryValue DECIMAL(18,6),
        @Amount DECIMAL(18,6),
        @CrDeAmt DECIMAL(18,6),
        @AdjType NVARCHAR(50),
        @AccountId INT,
        @PayeeId INT,
        @NewAdjAccountCode NVARCHAR(50),
        @IsDebit BIT,

        @QtyTolerance DECIMAL(18,6) = 0.000001,
        @ValueTolerance DECIMAL(18,6) = 0.005,
        @Cost DECIMAL(18,6),
        @RecentCost DECIMAL(18,6),
        -- >>> FIX: @RepairDelta moved here (was an inline DECLARE inside the Sales
        --     block) so Purchase / Adj-Q share the same absorb logic.
        @RepairDelta DECIMAL(18,6)

    -- >>> FIX: populate base-unit RecentCost. Was declared but never assigned, so
    --     @RecentCost was NULL -> NULLed COGS/InvValue on any sale from zero/negative
    --     stock. RecentCost lives on ItemUnit (base-unit row), not Item.
    SELECT @RecentCost = iu.RecentCost
    FROM dbo.ItemUnit iu
    WHERE iu.ItemId = @ItemId AND iu.IsBaseUnit = 1;

    -- >>> FIX 2026-07-07 (review): guard NULL RecentCost so it can't NULL-cascade the ledger on
    --     a sale from zero/negative stock. NULL -> 0 (never crash the whole item). WARNING: 0
    --     means any oversold/zero-stock sale for this item is costed at $0 (overstated margin) --
    --     fix the base-unit RecentCost in the item master. (A durable per-row warning belongs to
    --     the v9 warnings mechanism, not yet built; PRINT surfaces it on manual/verify runs.)
    IF @RecentCost IS NULL
    BEGIN
        SET @RecentCost = 0;
        PRINT 'RecalcQAV-v1 WARNING: ItemId ' + CAST(@ItemId AS varchar(12))
            + ' has no base-unit RecentCost; oversold/zero-stock sales costed at $0. Review item master.';
    END

    WHILE @RowNum <= @MaxRow
    BEGIN
        -- Fetch transaction meta info and the inventory row payload from the
        -- preloaded temp table. This keeps the loop logic unchanged while
        -- avoiding repeated point-lookups back into TransactionJournalDetail.
        SELECT
            @MyId = AutoId,
            @MyTxDate = TxDate,
            @MySourceDocOrder = SourceDocOrder,
            @MyTxDetailId = TxDetailId,
            @MySourceDocNum = SourceDocNum,
            @Qty = Qty,
            @Price = Price,
            @BillQty = BillQty,
            @PayeeId = PayeeId,
            @FactorToBase = FactorToBase,
            @AccountId = PairedAccountId
        FROM #QAVTable
        WHERE AutoId = @RowNum;

        --@InventoryValue only for Calculate AvgCost. has no other purpose.
        --When in Sales, AvgCost is not change.
        --@Amount is actual Value changed in 'INV'
        --There is miss leading think @InventoryValue relate to @Amount.
        --Final SUM(CASE WHEN t.SourceDocType='Sales' THEN TD.Qty*-1 ELSE TD.Qty END) AS Qty
        --SourceDocOrder in (300, 305, 680, 685), It is purchase
        --300 Old Purchase
        --305 Old Purchase Debit Memo
        --680 Cur Purchase
        --685 Cur Purchase Debit Memo
        --310 PayNow Check Purchase
        --320 PayNow Credit Card Purchase
        IF @MySourceDocOrder IN (300,305,310,320,680,685)
        BEGIN
            -- Step 1: Initialize
            SET @Price = ABS(@Price)  -- Always positive
            SET @CloQty = @LCloQty + @Qty  -- New inventory quantity

            -- Step 2: Calculate base purchase value
            SET @DiffInventoryValue = ROUND(@BillQty * @Price, 6)

            -- Step 3: Calculate COGS adjustment if needed
            SET @COGSAdjAmount = 0;

            IF @LCloQty < 0
            BEGIN
                IF @Qty > 0
                BEGIN
                    -- Purchase is recovering previously oversold inventory.
                    -- This one formula handles:
                    -- 1) still negative after purchase
                    -- 2) exactly back to zero
                    -- 3) recovered to positive inventory
                    DECLARE @RecoveredQty DECIMAL(18,6);
                    DECLARE @AssumedValue DECIMAL(18,6);
                    DECLARE @ActualValue DECIMAL(18,6);

                    IF ABS(@Qty) >= ABS(@LCloQty)
                        SET @RecoveredQty = ABS(@LCloQty);
                    ELSE
                        SET @RecoveredQty = ABS(@Qty);

                    SET @AssumedValue =
                        ABS(@LInventoryValue) * @RecoveredQty / ABS(@LCloQty);

                    SET @ActualValue =
                        @RecoveredQty * @Price;

                    SET @COGSAdjAmount =
                        ROUND(@ActualValue - @AssumedValue, 6);
                END
                ELSE IF @Qty < 0
                BEGIN
                    -- Purchase return while already negative.
                    -- This does not recover oversold inventory.
                    -- Keep separate from normal recovery logic.

                    SET @COGSAdjAmount =
                        ROUND(ABS(@Qty) * (@Price - @LAvgCost), 6) * -1;
                END
                ELSE IF @Qty = 0
                BEGIN
                    -- Value-only vendor adjustment while inventory is negative.
                    -- No quantity recovery, so the whole value change goes to COGS.

                    IF @BillQty > 0
                    BEGIN
                        SET @COGSAdjAmount =
                            ROUND(ABS(@BillQty) * @Price, 6);
                    END
                    ELSE IF @BillQty < 0
                    BEGIN
                        SET @COGSAdjAmount =
                            ROUND(ABS(@BillQty) * @Price, 6) * -1;
                    END
                END
            END

            -- Step 4: Inventory Amount must offset from COGS Adjustment (purchase + COGS correction)
            SET @Amount = ROUND(@DiffInventoryValue,2) - ROUND(@COGSAdjAmount,2)

            -- Step 5: Update final inventory value
            SET @InventoryValue = @LInventoryValue + @Amount

            -- Step 6: Normalize and derive AvgCost
            -- >>> OLD CODE COMMENTED OUT 2026-07-07
            --     Problem:
            --     Purchase has two accounting pieces:
            --         @INV  Amount = PurchaseValue - COGSAdj
            --         @COGS Amount = COGSAdj
            --
            --     The old normalize logic added material residual only to @Amount.
            --     That changed the @INV line but did not adjust @COGSAdjAmount,
            --     so the paired @COGS line could become out of balance.
            --
            -- IF ABS(@CloQty) <= @QtyTolerance
            -- BEGIN
            --     IF ABS(@InventoryValue) > @ValueTolerance
            --         SET @Amount = @Amount + (0 - @InventoryValue)
            --     SET @CloQty = 0
            --     SET @InventoryValue = 0
            --     SET @AvgCost = 0
            -- END
            -- ELSE
            -- BEGIN
            --     SET @AvgCost = ROUND(@InventoryValue / @CloQty, 6)
            -- END
            --
            -- >>> NEW PURCHASE-SPECIFIC NORMALIZE LOGIC 2026-07-07
            --     If Qty is near zero, final InvValue must become zero.
            --     If remaining InvValue is material, absorb it into this purchase.
            --     Because purchase has a paired @COGS line, also adjust
            --     @COGSAdjAmount by the opposite side so GL stays balanced.
            IF ABS(@CloQty) <= @QtyTolerance
            BEGIN
                IF ABS(@InventoryValue) > @ValueTolerance
                BEGIN
                    SET @RepairDelta = 0 - @InventoryValue;

                    -- Adjust @INV line amount
                    SET @Amount = @Amount + @RepairDelta;

                    -- Adjust paired @COGS line amount
                    -- Purchase paired COGS later posts @COGSAdjAmount.
                    SET @COGSAdjAmount = @COGSAdjAmount - @RepairDelta;
                END

                SET @CloQty = 0;
                SET @InventoryValue = 0;
                SET @AvgCost = 0;
            END
            ELSE
            BEGIN
                SET @AvgCost = ROUND(@InventoryValue / @CloQty, 6);
            END

            --UPDATE JOURNAL
            SET @Amount = ISNULL(@Amount, 0);

            IF @Amount = 0
                SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
            ELSE --IF @IsDebit = 1 --@INV
                SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;

            UPDATE TransactionJournalDetail SET
                ClosingQty = @CloQty,
                AverageCost = @AvgCost,
                InventoryValue = @InventoryValue,
                Amount = @Amount,
                CrDeAmount = @CrDeAmt
            WHERE TxDetailId = @MyTxDetailId

            --PAIRED ACCOUNT @COGS
            IF @AccountId = @COGSAccountId --'@COGS'
            BEGIN
                SET @Amount = ROUND(ISNULL(@COGSAdjAmount, 0), 2)

                IF @Amount = 0
                    SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
                ELSE --IF @IsDebit = 1 --@COGS
                    SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;

                UPDATE TransactionJournalDetail SET
                    Amount = @Amount,
                    CrDeAmount = @CrDeAmt
                WHERE TxDetailId = @MyTxDetailId - 1
            END
            ELSE
                SET @Amount = NULL; SET @CrDeAmt = NULL; --SET @DebitAmt = NULL; SET @CreditAmt = NULL;
        END

        --if SourceDocOrder is 500 then Sales
        ELSE IF @MySourceDocOrder IN (500,505)
        BEGIN
            -- Sales block core logic

            -- Sales: @Qty > 0 reduces inventory
            -- Return: @Qty < 0 increases inventory
            SET @CloQty = @LCloQty - @Qty;

            -- Step 1: Choose safe cost
            -- If we have positive stock and non-negative avg cost, use avg cost.
            -- Otherwise use RecentCost for oversold / zero-stock sale.
            IF @LCloQty > 0 AND @LAvgCost >= 0
                SET @Cost = @LAvgCost;
            ELSE
                SET @Cost = @RecentCost;  -- must be base-unit cost

            -- Step 2: Calculate value change
            SET @DiffInventoryValue = ROUND(@Qty * @Cost, 6) * -1;

            -- Step 3: New inventory value
            SET @InventoryValue = @LInventoryValue + @DiffInventoryValue;

            -- Step 4: Amount for @INV line
            SET @Amount = @DiffInventoryValue;

            -- Step 5: Normalize near-zero qty
            -- >>> FIX 2026-07-07: only ABSORB when residual is MATERIAL (> @ValueTolerance);
            --     dust is zeroed silently (was absorbing every residual -> micro GL postings).
            --     @RepairDelta declaration moved to the top DECLARE block.
            -- ---- prior version ----
            -- IF ABS(@CloQty) <= @QtyTolerance
            -- BEGIN
            --     -- absorb remaining value into this transaction
            --     DECLARE @RepairDelta DECIMAL(18,6);
            --     SET @RepairDelta = 0 - @InventoryValue;
            --     SET @Amount = @Amount + @RepairDelta;
            --     SET @CloQty = 0;
            --     SET @InventoryValue = 0;
            --     SET @AvgCost = 0;
            -- END
            IF ABS(@CloQty) <= @QtyTolerance
            BEGIN
                IF ABS(@InventoryValue) > @ValueTolerance
                BEGIN
                    -- absorb remaining material value into this transaction
                    SET @RepairDelta = 0 - @InventoryValue;
                    SET @Amount = @Amount + @RepairDelta;
                END

                SET @CloQty = 0;
                SET @InventoryValue = 0;
                SET @AvgCost = 0;
            END
            ELSE
            BEGIN
                SET @AvgCost = ROUND(@InventoryValue / @CloQty, 6);
            END

            --UPDATE JOURNAL
            SET @Amount = ISNULL(@Amount, 0);

            IF @Amount = 0
                SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
            ELSE --IF @IsDebit = 1 --@INV
                SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;

            UPDATE TransactionJournalDetail SET
                ClosingQty = @CloQty,
                AverageCost = @AvgCost,
                InventoryValue = @InventoryValue,
                Amount = @Amount,
                CrDeAmount = @CrDeAmt
            WHERE TxDetailId = @MyTxDetailId

            --PAIRED ACCOUNT @COGS RECALC
            IF @AccountId = @COGSAccountId--'@COGS'
            BEGIN
                SET @Amount=ISNULL(-@Amount,0)

                IF @Amount = 0
                    SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
                ELSE --IF @IsDebit = 1 --@COGS
                    SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;

                UPDATE TransactionJournalDetail SET
                    Amount = @Amount,
                    CrDeAmount = @CrDeAmt
                WHERE TxDetailId = @MyTxDetailId-1
            END
            ELSE
                SET @Amount = NULL; SET @CrDeAmt = NULL; --SET @DebitAmt = NULL; SET @CreditAmt = NULL;
        END

        -- Inventory adjustments now use:
        -- 600 = Before Receiving
        -- 695 = After Receiving
        -- as an active inventory-adjustment posting order.
        ELSE IF @MySourceDocOrder IN (600, 695)
        BEGIN
            SELECT @AdjType = AdjType
            FROM InventoryAdj
            WHERE AdjNumber = @MySourceDocNum

            IF @AdjType = 'Q' -- Quantity Adjustment
            BEGIN
                -- Q = Quantity Adjustment
                DECLARE @AdjQty DECIMAL(18,6);

                -- @Qty is the final counted quantity
                SET @CloQty = @Qty;

                -- Difference between physical count and previous system qty
                SET @AdjQty = @CloQty - @LCloQty;

                -- Use safe cost
                IF @LCloQty > 0 AND @LAvgCost >= 0
                    SET @Cost = @LAvgCost;
                ELSE
                    SET @Cost = @RecentCost; -- base-unit cost

                -- Value change caused by quantity adjustment
                SET @DiffInventoryValue = ROUND(@AdjQty * @Cost, 6);

                SET @InventoryValue = @LInventoryValue + @DiffInventoryValue;

                SET @Amount = @DiffInventoryValue;

                -- Normalize zero qty
                -- >>> FIX 2026-07-07: absorb only MATERIAL residual; dust zeroed silently.
                -- ---- prior version ----
                -- IF ABS(@CloQty) <= @QtyTolerance
                -- BEGIN
                --     SET @RepairDelta = 0 - @InventoryValue;
                --     SET @Amount = @Amount + @RepairDelta;
                --     SET @CloQty = 0;
                --     SET @InventoryValue = 0;
                --     SET @AvgCost = 0;
                -- END
                IF ABS(@CloQty) <= @QtyTolerance
                BEGIN
                    IF ABS(@InventoryValue) > @ValueTolerance
                    BEGIN
                        SET @RepairDelta = 0 - @InventoryValue;
                        SET @Amount = @Amount + @RepairDelta;
                    END

                    SET @CloQty = 0;
                    SET @InventoryValue = 0;
                    SET @AvgCost = 0;
                END
                ELSE
                BEGIN
                    SET @AvgCost = ROUND(@InventoryValue / @CloQty, 6);
                END

                --UPDATE JOURNAL
                SET @Amount = ISNULL(@Amount, 0);

                IF @Amount = 0
                    SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
                ELSE --IF @IsDebit = 1 --@INV
                    SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;

                UPDATE TransactionJournalDetail SET
                    ClosingQty = @CloQty,
                    AverageCost = @AvgCost,
                    InventoryValue = @InventoryValue,
                    Amount = @Amount,
                    CrDeAmount = @CrDeAmt
                WHERE TxDetailId = @MyTxDetailId

                -- PAIRED ACCOUNT (@IINVG, @EINVL, @ARE) RECALC
                IF @Amount >= 0
                BEGIN
                    SET @AccountId = @InvGainAccountId --'@IINVG'
                    SET @IsDebit=0
                END
                ELSE IF @Amount < 0
                BEGIN
                    SET @AccountId =
                    CASE
                        WHEN @PayeeId IS NULL THEN @InvLossAccountId --'@EINVL'
                        ELSE @AREAccountId --'@ARE'
                    END

                    SET @Amount = -(@Amount)
                    SET @IsDebit=1
                END

                IF @Amount = 0
                    SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
                ELSE IF @IsDebit = 1  -- Debit-normal account (Asset, Expense)
                    SET @CrDeAmt = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
                ELSE IF @IsDebit = 0  -- Credit-normal account (Liability, Equity, Revenue)
                    SET @CrDeAmt = CASE WHEN @Amount > 0 THEN ABS(@Amount) ELSE -ABS(@Amount) END;

                UPDATE TransactionJournalDetail SET
                    AccountId = @AccountId,
                    Amount = @Amount,
                    CrDeAmount = @CrDeAmt
                WHERE TxDetailId = @MyTxDetailId - 1
            END
            ELSE IF @AdjType = 'V' -- Value Adjustment
            BEGIN
                -- V = Value Adjustment
                DECLARE @TargetInventoryValue DECIMAL(18,6);

                -- @Price is the new unit cost
                SET @Price = ABS(@Price);

                -- Quantity does not change
                SET @CloQty = @LCloQty;

                -- New target inventory value
                SET @TargetInventoryValue = ROUND(@CloQty * @Price, 6);

                -- Adjustment amount
                SET @DiffInventoryValue = @TargetInventoryValue - @LInventoryValue;

                -- Final inventory value
                SET @InventoryValue = @TargetInventoryValue;

                -- INV amount
                SET @Amount = @DiffInventoryValue;

                -- Normalize zero qty
                IF ABS(@CloQty) <= @QtyTolerance
                BEGIN
                    SET @CloQty = 0;
                    SET @InventoryValue = 0;
                    SET @AvgCost = 0;

                    -- If old value existed, amount should clear it
                    SET @Amount = 0 - @LInventoryValue;
                END
                ELSE
                BEGIN
                    SET @AvgCost = ROUND(@InventoryValue / @CloQty, 6);
                END

                --UPDATE JOURNAL
                SET @Amount = ISNULL(@Amount, 0);

                IF @Amount = 0
                    SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
                ELSE --IF @IsDebit = 1 --@INV
                    SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;

                UPDATE TransactionJournalDetail SET
                    ClosingQty = @CloQty,
                    AverageCost = @AvgCost,
                    InventoryValue = @InventoryValue,
                    Amount = @Amount,
                    CrDeAmount = @CrDeAmt
                WHERE TxDetailId = @MyTxDetailId

                -- PAIRED ACCOUNT (@IINVG, @EINVL, @ARE) RECALC
                IF @Amount >= 0
                BEGIN
                    SET @AccountId = @InvGainAccountId --'@IINVG'
                    SET @IsDebit=0
                END
                ELSE IF @Amount < 0
                BEGIN
                    SET @AccountId =
                    CASE
                        WHEN @PayeeId IS NULL THEN @InvLossAccountId --'@EINVL'
                        ELSE @AREAccountId --'@ARE'
                    END

                    SET @Amount = -(@Amount)
                    SET @IsDebit=1
                END

                IF @Amount = 0
                    SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
                ELSE IF @IsDebit = 1  -- Debit-normal account (Asset, Expense)
                    SET @CrDeAmt = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
                ELSE IF @IsDebit = 0  -- Credit-normal account (Liability, Equity, Revenue)
                    SET @CrDeAmt = CASE WHEN @Amount > 0 THEN ABS(@Amount) ELSE -ABS(@Amount) END;

                UPDATE TransactionJournalDetail SET
                    AccountId = @AccountId,
                    Amount = @Amount,
                    CrDeAmount = @CrDeAmt
                WHERE TxDetailId = @MyTxDetailId - 1
            END
            ELSE IF @AdjType = 'B' -- Quantity & Value Adjustment
            BEGIN
                -- B = Quantity + Value Adjustment
                -- @Qty is final physical count
                -- @Price is new unit cost

                SET @Price = ABS(@Price);

                -- Set closing quantity to physical count
                SET @CloQty = @Qty;

                -- Set target inventory value
                SET @InventoryValue = ROUND(@CloQty * @Price, 6);

                -- Adjustment amount for accounting
                SET @Amount = @InventoryValue - @LInventoryValue;

                -- Normalize zero qty
                IF ABS(@CloQty) <= @QtyTolerance
                BEGIN
                    SET @CloQty = 0;
                    SET @InventoryValue = 0;
                    SET @AvgCost = 0;

                    -- Clear old inventory value
                    SET @Amount = 0 - @LInventoryValue;
                END
                ELSE
                BEGIN
                    SET @AvgCost = ROUND(@InventoryValue / @CloQty, 6);
                END

                --UPDATE JOURNAL
                SET @Amount = ISNULL(@Amount, 0);

                IF @Amount = 0
                    SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
                ELSE --IF @IsDebit = 1 --@INV
                    SET @CrDeAmt  = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;

                UPDATE TransactionJournalDetail SET
                    ClosingQty = @CloQty,
                    AverageCost = @AvgCost,
                    InventoryValue = @InventoryValue,
                    Amount = @Amount,
                    CrDeAmount = @CrDeAmt
                WHERE TxDetailId = @MyTxDetailId

                --PAIRED ACCOUNT (@IINVG, @EINVL, @ARE) RECALC
                IF @Amount >= 0
                BEGIN
                    SET @AccountId = @InvGainAccountId --'@IINVG'
                    SET @IsDebit=0
                END
                ELSE IF @Amount < 0
                BEGIN
                    SET @AccountId =
                    CASE
                        WHEN @PayeeId IS NULL THEN @InvLossAccountId --'@EINVL'
                        ELSE @AREAccountId --'@ARE'
                    END

                    SET @Amount = -(@Amount)
                    SET @IsDebit=1
                END

                IF @Amount = 0
                    SET @CrDeAmt = 0; --SET @DebitAmt = 0; SET @CreditAmt = 0;
                ELSE IF @IsDebit = 1  -- Debit-normal account (Asset, Expense)
                    SET @CrDeAmt = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
                ELSE IF @IsDebit = 0  -- Credit-normal account (Liability, Equity, Revenue)
                    SET @CrDeAmt = CASE WHEN @Amount > 0 THEN ABS(@Amount) ELSE -ABS(@Amount) END;

                UPDATE TransactionJournalDetail SET
                    AccountId = @AccountId,
                    Amount = @Amount,
                    CrDeAmount = @CrDeAmt
                WHERE TxDetailId = @MyTxDetailId - 1
            END
            ELSE IF @AdjType = 'C' -- Convert/Repack
            BEGIN
                -- Delta-based qty (not absolute like 'Q')
                SET @CloQty = @LCloQty + @Qty

                IF @Qty > 0  -- Destination: recalc avg cost (purchase behavior)
                BEGIN
                    SET @Price = ABS(@Price)

                    IF @CloQty > 0
                        SET @AvgCost = ROUND((@LInventoryValue + (@Qty * @Price)) / @CloQty, 6)
                    ELSE
                        SET @AvgCost = @Price

                    SET @InventoryValue = ROUND(@CloQty * @AvgCost, 6)
                    SET @Amount = @InventoryValue - @LInventoryValue
                END
                ELSE  -- Source: keep avg cost (sales behavior)
                BEGIN
                    SET @AvgCost = @LAvgCost
                    SET @InventoryValue = ROUND(@CloQty * @AvgCost, 6)
                    SET @Amount = @InventoryValue - @LInventoryValue
                END

                -- @INV line update
                SET @Amount = ISNULL(@Amount, 0);

                IF @Amount = 0
                    SET @CrDeAmt = 0;
                ELSE
                    SET @CrDeAmt = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;

                UPDATE TransactionJournalDetail SET
                    ClosingQty = @CloQty,
                    AverageCost = @AvgCost,
                    InventoryValue = @InventoryValue,
                    Amount = @Amount,
                    CrDeAmount = @CrDeAmt
                WHERE TxDetailId = @MyTxDetailId

                -- Offset line (same gain/loss pattern as other adj types)
                IF @Amount >= 0
                BEGIN
                    SET @AccountId = @InvGainAccountId
                    SET @IsDebit = 0
                END
                ELSE
                BEGIN
                    SET @AccountId = CASE WHEN @PayeeId IS NULL THEN @InvLossAccountId ELSE @AREAccountId END
                    SET @Amount = -(@Amount)
                    SET @IsDebit = 1
                END

                IF @Amount = 0
                    SET @CrDeAmt = 0;
                ELSE IF @IsDebit = 1
                    SET @CrDeAmt = CASE WHEN @Amount > 0 THEN -ABS(@Amount) ELSE ABS(@Amount) END;
                ELSE IF @IsDebit = 0
                    SET @CrDeAmt = CASE WHEN @Amount > 0 THEN ABS(@Amount) ELSE -ABS(@Amount) END;

                UPDATE TransactionJournalDetail SET
                    AccountId = @AccountId,
                    Amount = @Amount,
                    CrDeAmount = @CrDeAmt
                WHERE TxDetailId = @MyTxDetailId - 1
            END
        END

        ELSE IF @MySourceDocOrder = 100 --OBE
        BEGIN
            -- OBE: Opening Balance Entry
            -- Don't recalculate Amount - preserve the exact ledger value as posted.
            -- This avoids Qty*Price rounding drift that unbalances the balance sheet.
            -- Step 1
            SET @CloQty = @Qty;

            -- Step 2
            SELECT @Amount = ISNULL(Amount,0)
            FROM TransactionJournalDetail
            WHERE TxDetailId = @MyTxDetailId;

            -- Step 3
            SET @InventoryValue = @LInventoryValue + @Amount;

            -- Step 4
            IF ABS(@CloQty) <= @QtyTolerance
            BEGIN
                SET @CloQty = 0;
                SET @InventoryValue = 0;
                SET @AvgCost = 0;
            END
            ELSE
            BEGIN
                SET @AvgCost = ROUND(@InventoryValue / @CloQty, 6);
            END

            --UPDATE JOURNAL
            UPDATE TransactionJournalDetail SET
                ClosingQty = @CloQty,
                AverageCost = @AvgCost,
                InventoryValue = @InventoryValue
            WHERE TxDetailId = @MyTxDetailId
        END

        SET @LCloQty = @CloQty
        SET @LAvgCost = @AvgCost
        SET @LInventoryValue = @InventoryValue

        SET @RowNum += 1
    END

    DROP TABLE #QAVTable;
END




