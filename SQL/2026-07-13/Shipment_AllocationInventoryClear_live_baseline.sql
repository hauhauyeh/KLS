
CREATE   PROCEDURE [dbo].[Shipment_AllocationInventoryClear]
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @PurchaseNumber INT,
        @ArrivalDate DATE,
        @StageId INT,
        @TxId BIGINT,
        @PayeeId INT,
        @InvClearAccountId INT,
        @InvAccountId INT,
        @CommissionAccountId INT;

    -- Purchase header
    SELECT 
        @PurchaseNumber = p.PurchaseNumber,
        @ArrivalDate = p.ArrivalDate,
        @StageId = p.StageId,
        @PayeeId = p.PayeeId
    FROM dbo.Purchase p
    WHERE p.PurchaseId = @PurchaseId;

    -- Only for Billed stage
    IF @StageId <> 6 
        RETURN;

    -- Get accounts
    SELECT TOP (1) @InvClearAccountId = a.AccountId
    FROM dbo.Account a
    WHERE a.AccountCode = '@INVC';

    SELECT TOP (1) @InvAccountId = a.AccountId
    FROM dbo.Account a
    WHERE a.AccountCode = '@INV';

    SELECT TOP (1) @CommissionAccountId = a.AccountId
    FROM dbo.Account a
    WHERE a.AccountCode = '@APC';

    -- Find TxId
    SELECT @TxId = tj.TxId
    FROM dbo.TransactionJournal tj
    WHERE tj.SourceDocType = 'Purchase'
      AND tj.SourceDocNumber = @PurchaseNumber;

    IF @TxId IS NULL OR @InvClearAccountId IS NULL OR @InvAccountId IS NULL
        RETURN;

    BEGIN TRY

        -- Detect if there WAS previous allocation before MERGE operations clear/update them.
        -- Needed so that removing all allocation still triggers recalc for all items.
        DECLARE @HadPreviousAllocation BIT = 0;

        IF EXISTS (
            SELECT 1 FROM dbo.TransactionJournalDetail
            WHERE TxId = @TxId
              AND AccountId IN (@InvClearAccountId, @CommissionAccountId)
              AND SourceDetailId IS NULL
        )
            SET @HadPreviousAllocation = 1;

        IF OBJECT_ID('tempdb..#TxImpact') IS NOT NULL DROP TABLE #TxImpact;

        SELECT
            pd.PurchaseDetailId,
            pd.ItemId,
            pd.FinalPrice,
            -- 2026-07-07 Effort-B InventoryClear: source ReceiveQty (physical) + FinalQty (entered value)
            -- from pd. ReceiveQty = landed spread denominator (physical axis); FinalQty = invariant guard.
            pd.ReceiveQty,
            pd.FinalQty,
            ISNULL(pd.LandedCost, 0) AS LandedCost,
            ISNULL(pd.ImportCommission, 0) AS ImportCommission
        INTO #TxImpact
        FROM dbo.PurchaseDetail pd
        JOIN Item i ON pd.ItemId = i.ItemId
        WHERE pd.PurchaseId = @PurchaseId
        AND i.ItemType = 'Inventory'
          AND pd.ItemId IS NOT NULL;

        -- 2026-07-07 Effort-B InventoryClear: landed invariant guard (fail fast BEFORE any write).
        -- Landed is only representable via @INV BillQty x Price in valid State 1: Receive = Final AND Receive > 0.
        -- Reject Receive <= 0 (incl. zero/zero) OR Receive <> Final (free-with-freight / billed-not-received /
        -- invalid both->0-unequal); otherwise the landed value would be lost/partial. Verified 0 such rows 2026-07-07.
        -- Lift this guard when the RecalcQAV physical-axis landed change lands (InventoryValue += Qty x landed/phys).
        IF EXISTS (
            SELECT 1 FROM #TxImpact x
            WHERE (ISNULL(x.LandedCost,0) + ISNULL(x.ImportCommission,0)) > 0
              AND ( ISNULL(x.ReceiveQty,0) <= 0
                    OR ISNULL(x.ReceiveQty,0) <> ISNULL(x.FinalQty,0) )
        )
            RAISERROR('Shipment_AllocationInventoryClear: landed line not in valid State 1 (Receive=Final AND Receive>0); landed via BillQty*Price would be lost/partial. Requires the RecalcQAV physical-axis landed fix.', 16, 1);

        --------------------------------------------------------------------
        -- (2) If LandedCost = 0 -> delete existing INVC TxDetail lines
        --------------------------------------------------------------------
        DECLARE @InvClearTotal DECIMAL(18,2);
        DECLARE @CommissionTotal DECIMAL(18,2);
        DECLARE @InvClearCrDe DECIMAL(18,2);
        DECLARE @CommissionCrDe DECIMAL(18,2);

        SELECT @InvClearTotal = SUM(x.LandedCost),
        @CommissionTotal = SUM(x.ImportCommission)
        FROM #TxImpact x;

        SET @InvClearTotal = @InvClearTotal * -1;
        EXEC dbo.Fn_Adjust_CrDeAmount '@INVC', @InvClearTotal, @InvClearCrDe OUTPUT;
        EXEC dbo.Fn_Adjust_CrDeAmount '@APC', @CommissionTotal, @CommissionCrDe OUTPUT;

        IF ABS(ISNULL(@InvClearTotal,0)) < 0.01
        BEGIN
            DELETE FROM dbo.TransactionJournalDetail
            WHERE TxId = @TxId
              AND AccountId = @InvClearAccountId
              AND SourceDetailId IS NULL;
        END
        ELSE
        BEGIN
            MERGE dbo.TransactionJournalDetail AS tgt
            USING (SELECT @TxId AS TxId) AS src
            ON  tgt.TxId = src.TxId
            AND tgt.AccountId = @InvClearAccountId
            AND tgt.SourceDetailId IS NULL
            WHEN MATCHED THEN
                UPDATE SET
                    tgt.PayeeId = @PayeeId,
                    tgt.ItemId = NULL,
                    tgt.Qty = 0,
                    tgt.Price = 0,
                    tgt.BillQty = 0,
                    tgt.FactorToBase = 1,
                    tgt.Amount = @InvClearTotal,
                    tgt.CrDeAmount = @InvClearCrDe,  -- credit positive
                    tgt.Notes = 'Inventory Clear (Total)'
            WHEN NOT MATCHED THEN
                INSERT (
                    TxId, SourceDetailId, AccountId, PayeeId, ItemId,
                    Qty, Price, BillQty, FactorToBase,
                    Amount, CrDeAmount, Notes
                )
                VALUES (
                    @TxId, NULL, @InvClearAccountId, @PayeeId, NULL,
                    0, 0, 0, 1,
                    @InvClearTotal, @InvClearCrDe, 'Inventory Clear (Total)'
                );
        END


        ----Insert/delete Commission account
        IF ABS(ISNULL(@CommissionTotal,0)) < 0.01
        BEGIN
            DELETE FROM dbo.TransactionJournalDetail
            WHERE TxId = @TxId
              AND AccountId = @CommissionAccountId
              AND SourceDetailId IS NULL;
        END
        ELSE
        BEGIN
            MERGE dbo.TransactionJournalDetail AS tgt
            USING (SELECT @TxId AS TxId) AS src
            ON  tgt.TxId = src.TxId
            AND tgt.AccountId = @CommissionAccountId
            AND tgt.SourceDetailId IS NULL
            WHEN MATCHED THEN
                UPDATE SET
                    tgt.PayeeId = @PayeeId,
                    tgt.ItemId = NULL,
                    tgt.Qty = 0,
                    tgt.Price = 0,
                    tgt.BillQty = 0,
                    tgt.FactorToBase = 1,
                    tgt.Amount = @CommissionTotal,
                    tgt.CrDeAmount = @CommissionCrDe,  -- credit positive
                    tgt.Notes = 'Commission Total'
            WHEN NOT MATCHED THEN
                INSERT (
                    TxId, SourceDetailId, AccountId, PayeeId, ItemId,
                    Qty, Price, BillQty, FactorToBase,
                    Amount, CrDeAmount, Notes
                )
                VALUES (
                    @TxId, NULL, @CommissionAccountId, @PayeeId, NULL,
                    0, 0, 0, 1,
                    @CommissionTotal, @CommissionCrDe, 'Commission Total'
                );
        END

        --------------------------------------------------------------------
        -- (3) Normalize the inventory @INV row to ENTERED basis (Option B).
        --     Price    = FinalPrice + (LandedCost + ImportCommission) / ReceiveQty  (per PHYSICAL unit spread)
        --     BillQty  = FinalQty        (entered value)
        --     FactorToBase = ReceiveQty  (EntQty, audit)
        --     Qty (BaseReceiveQty) unchanged; Amount/CrDeAmount/InventoryValue stay RecalcQAV-owned.
        -- 2026-07-07 (Effort-B): was "Price = FinalPrice + LandedCost + ImportCommission (TOTAL)" -- that
        --     described the old total-add model; landed now spreads per-unit over the physical ReceiveQty.
        --------------------------------------------------------------------
        UPDATE inv
            -- 2026-07-07 Effort-B InventoryClear (Option B -- normalize the FULL @INV value basis here):
            --   Price + BillQty + FactorToBase are ALL flipped to entered basis in this ONE statement,
            --   sourced from pd (#TxImpact). Why the paired fields, not Price alone: this UPDATE rebuilds
            --   Price for EVERY inventory @INV row of the purchase (changed + partial-update SURVIVOR rows,
            --   ChangeStatus=NULL, which the writer never re-touches). Flipping Price to entered while leaving a
            --   survivor's BillQty base would MIX basis -> BillQty x Price undervalues (even divide-only). So
            --   normalize the paired value fields together -> billed @INV rows are self-corrected every run.
            --   * Price: drop (x.FinalPrice * ISNULL(inv.FactorToBase,1)) -> x.FinalPrice (entered goods);
            --     landed spread denominator inv.BillQty -> x.ReceiveQty (physical; guarded to Receive>0 above).
            --   * BillQty -> x.FinalQty (entered value).  * FactorToBase slot -> x.ReceiveQty (EntQty, audit).
            -- OLD (price-only, base-reading):
            -- SET inv.Price = ROUND(
            --     (x.FinalPrice * ISNULL(inv.FactorToBase, 1))
            --     + CASE WHEN ISNULL(inv.BillQty, 0) = 0 THEN 0
            --            ELSE (x.LandedCost + x.ImportCommission) / NULLIF(inv.BillQty, 0) END
            --     ,6)
            SET inv.Price = ROUND(
            x.FinalPrice
            + CASE
                WHEN ISNULL(x.ReceiveQty, 0) = 0 THEN 0
                ELSE (
                (x.LandedCost + x.ImportCommission) / x.ReceiveQty
                )
              END
            ,6),
            inv.BillQty      = x.FinalQty,      -- normalize survivor rows too: entered value
            inv.FactorToBase = x.ReceiveQty     -- EntQty (audit)
        FROM dbo.TransactionJournalDetail inv
        INNER JOIN #TxImpact x
            ON x.PurchaseDetailId = inv.SourceDetailId
           AND x.ItemId = inv.ItemId
        WHERE inv.TxId = @TxId
          AND inv.AccountId = @InvAccountId;

        /* ---------------------------------------------------------
           Fix rounding residue: push remaining landed cost
           to the Rounding Off so Tx balances.
        --------------------------------------------------------- */

        DECLARE @Residue DECIMAL(18,6) = 0;
        DECLARE @RoundOffAccountId INT;

        -- Change '@RND' to your rounding account code
        SELECT TOP (1) @RoundOffAccountId = a.AccountId
        FROM dbo.Account a
        WHERE a.AccountCode = '@ERO';

        -- Total residue across all lines
        -- 2026-07-07 Effort-B InventoryClear: mirror the Price-spread basis — landed per-unit divides
        -- by physical x.ReceiveQty (not inv.BillQty). The multiplier stays inv.BillQty (the qty Price is
        -- multiplied by in the @INV InventoryValue). Identical on valid State-1 data (Receive = Final).
        SELECT @Residue =
            SUM(x.LandedCost+x.ImportCommission)
            -- OLD: - SUM(ROUND((x.LandedCost+x.ImportCommission) / NULLIF(inv.BillQty,0), 6) * inv.BillQty)
            - SUM(ROUND((x.LandedCost+x.ImportCommission) / NULLIF(x.ReceiveQty,0), 6) * inv.BillQty)
        FROM #TxImpact x
        JOIN dbo.TransactionJournalDetail inv
          ON inv.TxId = @TxId
         AND inv.SourceDetailId = x.PurchaseDetailId
         AND inv.ItemId = x.ItemId
         AND inv.AccountId = @InvAccountId
        WHERE ISNULL(inv.BillQty,0) > 0;

        IF @RoundOffAccountId IS NULL
            RETURN;

        IF ABS(ISNULL(@Residue, 0)) < 0.01
        BEGIN
            DELETE FROM dbo.TransactionJournalDetail
            WHERE TxId = @TxId
              AND AccountId = @RoundOffAccountId
              AND SourceDetailId IS NULL
        END
        ELSE
        BEGIN
            DECLARE @Amt DECIMAL(18,2) = ABS(@Residue);
            DECLARE @CrDe DECIMAL(18,2) =
                CASE WHEN @Residue > 0 THEN -ABS(@Residue) ELSE ABS(@Residue) END;

            MERGE dbo.TransactionJournalDetail AS tgt
            USING (
                SELECT
                    @TxId AS TxId,
                    @RoundOffAccountId AS AccountId,
                    @PayeeId AS PayeeId,
                    @Amt AS Amount,
                    @CrDe AS CrDeAmount
            ) AS src
            ON  tgt.TxId = src.TxId
            AND tgt.AccountId = src.AccountId
            AND tgt.SourceDetailId IS NULL 
            WHEN MATCHED THEN
                UPDATE SET
                    tgt.PayeeId = src.PayeeId,
                    tgt.ItemId = NULL,
                    tgt.Qty = 0,
                    tgt.Price = 0,
                    tgt.BillQty = 0,
                    tgt.FactorToBase = 1,
                    tgt.Amount = src.Amount,
                    tgt.CrDeAmount = src.CrDeAmount,
                    tgt.Notes = 'Landed Cost Rounding'
            WHEN NOT MATCHED THEN
                INSERT (TxId,  
                AccountId, 
                PayeeId, 
                ItemId,
                Qty, 
                Price, 
                BillQty, 
                FactorToBase,
                Amount, 
                CrDeAmount, 
                Notes)
                VALUES 
                (src.TxId, 
                src.AccountId, 
                src.PayeeId, 
                NULL,
                0, 
                0, 
                0, 
                1,
                src.Amount, 
                src.CrDeAmount, 
                'Landed Cost Rounding');
        END

        --------------------------------------------------------------------
        -- (4) Conditional recalc: queue all inventory items only when
        --     allocation is active now OR was active before this run.
        --     If neither, the caller already queued only changed items.
        --------------------------------------------------------------------

        DECLARE @HasAllocation BIT = 0;

        IF EXISTS (
            SELECT 1 FROM #TxImpact
            WHERE LandedCost > 0 OR ImportCommission > 0
        )
            SET @HasAllocation = 1;

        IF @HasAllocation = 1 OR @HadPreviousAllocation = 1
        BEGIN
            INSERT INTO RecalculationLog(ItemId, TxId, TxDate)
            SELECT DISTINCT ItemId, @TxId, @ArrivalDate
            FROM #TxImpact;
        END

        -- Always update recent cost (FinalPrice may have changed regardless of allocation)
        EXEC [ItemUnit_UpdateRecentCost] @PurchaseId,0

    END TRY
    BEGIN CATCH
      THROW;
    END CATCH
END;



