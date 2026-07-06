-- =============================================================================
-- TempBombSales_Save -- deploy (DROP + CREATE). Working file per SP workflow.
-- 2026-07-05: Phase B (last sales-side site) -- base qty derives from ItemUnitId ->
--   ItemUnit (single source of truth) via dbo.Fn_QtyToBase, INNER JOIN ItemUnit.
--   TWO spots:
--     Spot 1 -- #LineUpdates population (from TempBombSales t): base qty feeds the @INV
--              journal (steps 14/15) + SalesDetail. INNER JOIN ItemUnit on t.ItemUnitId
--              (always a real unit -- C# ApplyUnit sets it; never drops).
--     Spot 2 -- step 20 refresh over all changed-sale SalesDetail (stored columns only):
--              INNER JOIN ItemUnit on sd.ItemUnitId (item lines only).
--   Identity today (all MultipleToBase=1). Retires t.FactorToBase / sd.FactorToBase from the
--   base-qty computes. Same signature as Sales_Insert / Sales_PartialUpdate / DropShipment.
-- Baseline: KLS/SQL/2026-07-05/TempBombSales_Save_live_baseline.sql
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[TempBombSales_Save]
GO

CREATE PROCEDURE [dbo].[TempBombSales_Save]
    @EmpId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -------------------------------------------------------------------------
    -- 1. Resolve required account ids.
    --    These are the same posting accounts used by Sales_PartialUpdate.
    -------------------------------------------------------------------------
    DECLARE
        @ARAccountId      INT,
        @FSTPAccountId    INT,
        @ISALEAccountId   INT,
        @ICREDITAccountId INT,
        @COGSAccountId    INT,
        @INVAccountId     INT,
        @LockCount        INT;

    SELECT @ARAccountId      = AccountId FROM Account WHERE AccountCode = '@AR';
    SELECT @FSTPAccountId    = AccountId FROM Account WHERE AccountCode = '@FSTP';
    SELECT @ISALEAccountId   = AccountId FROM Account WHERE AccountCode = '@ISALE';
    SELECT @ICREDITAccountId = AccountId FROM Account WHERE AccountCode = '@ICREDIT';
    SELECT @COGSAccountId    = AccountId FROM Account WHERE AccountCode = '@COGS';
    SELECT @INVAccountId     = AccountId FROM Account WHERE AccountCode = '@INV';

    IF @ARAccountId IS NULL
       OR @FSTPAccountId IS NULL
       OR @ISALEAccountId IS NULL
       OR @ICREDITAccountId IS NULL
       OR @COGSAccountId IS NULL
       OR @INVAccountId IS NULL
    BEGIN
        RAISERROR('One or more required posting accounts are missing.', 16, 1);
        RETURN;
    END;

    -------------------------------------------------------------------------
    -- 2. Capture affected SalesIds once.
    --    This is important because TempBombSales is deleted at the end.
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#ChangedSales') IS NOT NULL
        DROP TABLE #ChangedSales;

    CREATE TABLE #ChangedSales
    (
        SalesId INT NOT NULL PRIMARY KEY
    );

    INSERT INTO #ChangedSales (SalesId)
    SELECT DISTINCT SalesId
    FROM TempBombSales
    WHERE EmpId = @EmpId
      AND IsChanged = 1;

    IF NOT EXISTS (SELECT 1 FROM #ChangedSales)
    BEGIN
        DELETE FROM TempBombSales
        WHERE EmpId = @EmpId;

        RETURN;
    END;

    -------------------------------------------------------------------------
    -- 3. Temp table for Sales header + journal header info.
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#SalesTx') IS NOT NULL
        DROP TABLE #SalesTx;

    CREATE TABLE #SalesTx
    (
        SalesId        INT NOT NULL PRIMARY KEY,
        SalesNumber    INT NOT NULL,
        DocType        CHAR(2) NULL,
        JournalDocType NVARCHAR(100) NOT NULL,
        ShipDate       DATE NULL,
        PayeeId        INT NULL,
        TaxPercent     DECIMAL(18,4) NULL,
        TxId           BIGINT NOT NULL
    );

    -------------------------------------------------------------------------
    -- 4. Temp table for changed bomb lines.
    --    Primary key protects against duplicate TempBombSales rows for the same
    --    SalesDetailId. If duplicates exist, fix the temp data instead of
    --    updating the same SalesDetail multiple times.
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#LineUpdates') IS NOT NULL
        DROP TABLE #LineUpdates;

    CREATE TABLE #LineUpdates
    (
        SalesId            INT NOT NULL,
        SalesDetailId      INT NOT NULL,
        TxId               BIGINT NOT NULL,
        ShipDate           DATE NULL,
        PayeeId            INT NULL,

        OldItemId          INT NULL,
        NewItemId          INT NULL,
        ItemUnitId         INT NULL,
        Unit               NVARCHAR(50) NULL,

        OrdQty             DECIMAL(18,2) NULL,
        ShipQty            DECIMAL(18,2) NULL,
        BillQty            DECIMAL(18,2) NULL,
        UnitPrice          DECIMAL(18,2) NULL,
        ExtTotal           DECIMAL(18,2) NULL,

        Notes              NVARCHAR(300) NULL,
        IsTaxable          BIT NOT NULL,
        OrgPrice           DECIMAL(18,2) NULL,
        DiscountPercent    DECIMAL(18,4) NULL,
        FactorToBase       DECIMAL(18,6) NULL,

        BaseOrdQty         DECIMAL(18,6) NULL,
        BaseShipQty        DECIMAL(18,6) NULL,
        BaseBillQty        DECIMAL(18,6) NULL,

        ItemType           NVARCHAR(100) NULL,
        IsUserOverWrite    BIT NULL,

        NewSalesAccountId  INT NOT NULL,
        NewSalesAccountCode NVARCHAR(20) NOT NULL,
        OldSalesAccountId  INT NULL,

        PRIMARY KEY (SalesId, SalesDetailId)
    );

    -------------------------------------------------------------------------
    -- 5. Temp table for recalculated sales totals.
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#SalesTotals') IS NOT NULL
        DROP TABLE #SalesTotals;

    CREATE TABLE #SalesTotals
    (
        SalesId      INT NOT NULL PRIMARY KEY,
        SubTotal     DECIMAL(18,2) NOT NULL,
        TaxableTotal DECIMAL(18,2) NOT NULL,
        TaxTotal     DECIMAL(18,2) NOT NULL,
        SalesTotal   DECIMAL(18,2) NOT NULL
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        ---------------------------------------------------------------------
        -- 6. Lock affected Sales rows only.
        --    This prevents two users from posting the same SalesId together,
        --    but it does not lock unrelated SalesIds.
        ---------------------------------------------------------------------
        SELECT @LockCount = COUNT(*)
        FROM Sales s WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN #ChangedSales cs
            ON cs.SalesId = s.SalesId;

        ---------------------------------------------------------------------
        -- 7. Load Sales + TransactionJournal info.
        ---------------------------------------------------------------------
        INSERT INTO #SalesTx
        (
            SalesId,
            SalesNumber,
            DocType,
            JournalDocType,
            ShipDate,
            PayeeId,
            TaxPercent,
            TxId
        )
        SELECT
            s.SalesId,
            s.SalesNumber,
            s.DocType,
            CASE
                WHEN s.DocType = 'CM' THEN 'Sales Credit Memo'
                WHEN s.DocType = 'DM' THEN 'Sales Debit Memo'
                ELSE 'Sales'
            END AS JournalDocType,
            s.ShipDate,
            s.ShipId,
            s.TaxPercent,
            tj.TxId
        FROM Sales s
        INNER JOIN #ChangedSales cs
            ON cs.SalesId = s.SalesId
        INNER JOIN TransactionJournal tj
            ON tj.SourceDocNumber = s.SalesNumber
           AND tj.SourceDocType =
                CASE
                    WHEN s.DocType = 'CM' THEN 'Sales Credit Memo'
                    WHEN s.DocType = 'DM' THEN 'Sales Debit Memo'
                    ELSE 'Sales'
                END;

        IF EXISTS
        (
            SELECT 1
            FROM #ChangedSales cs
            LEFT JOIN #SalesTx st
                ON st.SalesId = cs.SalesId
            WHERE st.SalesId IS NULL
        )
        BEGIN
            RAISERROR('One or more Sales records or TransactionJournal records were not found.', 16, 1);
        END;

        ---------------------------------------------------------------------
        -- 8. Stage changed bomb lines.
        --    This represents the U/update branch from Sales_PartialUpdate.
        ---------------------------------------------------------------------
        INSERT INTO #LineUpdates
        (
            SalesId,
            SalesDetailId,
            TxId,
            ShipDate,
            PayeeId,

            OldItemId,
            NewItemId,
            ItemUnitId,
            Unit,

            OrdQty,
            ShipQty,
            BillQty,
            UnitPrice,
            ExtTotal,

            Notes,
            IsTaxable,
            OrgPrice,
            DiscountPercent,
            FactorToBase,

            BaseOrdQty,
            BaseShipQty,
            BaseBillQty,

            ItemType,
            IsUserOverWrite,

            NewSalesAccountId,
            NewSalesAccountCode,
            OldSalesAccountId
        )
        SELECT
            t.SalesId,
            t.SalesDetailId,
            st.TxId,
            st.ShipDate,
            st.PayeeId,

            sd.ItemId AS OldItemId,
            t.ItemId AS NewItemId,
            t.ItemUnitId,
            t.Unit,

            t.OrdQty,
            t.ShipQty,
            t.BillQty,
            t.UnitPrice,
            ROUND(t.BillQty * t.UnitPrice, 2) AS ExtTotal,

            t.Notes,
            ISNULL(t.IsTaxable, sd.IsTaxable) AS IsTaxable,
            t.OrgPrice,
            t.DiscountPercent,
            t.FactorToBase,

            -- 2026-07-05 (Phase B): base qty from ItemUnitId -> ItemUnit (source of truth) via
            -- dbo.Fn_QtyToBase (see INNER JOIN ItemUnit iu below). Feeds SalesDetail + @INV rows. Prior:
            -- ROUND(t.OrdQty  / NULLIF(t.FactorToBase, 0), 6) AS BaseOrdQty,
            -- ROUND(t.ShipQty / NULLIF(t.FactorToBase, 0), 6) AS BaseShipQty,
            -- ROUND(t.BillQty / NULLIF(t.FactorToBase, 0), 6) AS BaseBillQty,
            dbo.Fn_QtyToBase(t.OrdQty,  iu.MultipleToBase, iu.FactorToBase) AS BaseOrdQty,
            dbo.Fn_QtyToBase(t.ShipQty, iu.MultipleToBase, iu.FactorToBase) AS BaseShipQty,
            dbo.Fn_QtyToBase(t.BillQty, iu.MultipleToBase, iu.FactorToBase) AS BaseBillQty,

            i.ItemType,
            t.IsUserOverWrite,

            CASE
                WHEN ROUND(t.BillQty * t.UnitPrice, 2) < 0 THEN @ICREDITAccountId
                ELSE @ISALEAccountId
            END AS NewSalesAccountId,

            CASE
                WHEN ROUND(t.BillQty * t.UnitPrice, 2) < 0 THEN '@ICREDIT'
                ELSE '@ISALE'
            END AS NewSalesAccountCode,

            oldSale.AccountId AS OldSalesAccountId
        FROM TempBombSales t
        INNER JOIN #SalesTx st
            ON st.SalesId = t.SalesId
        INNER JOIN SalesDetail sd
            ON sd.SalesId = t.SalesId
           AND sd.SalesDetailId = t.SalesDetailId
        -- 2026-07-05 (Phase B): ItemUnit for base-qty conversion (source of truth). t.ItemUnitId is
        -- always a real unit (C# ApplyUnit sets it), so this INNER JOIN never drops a bomb line.
        INNER JOIN ItemUnit iu
            ON iu.ItemUnitId = t.ItemUnitId
        LEFT JOIN Item i
            ON i.ItemId = t.ItemId
        OUTER APPLY
        (
            SELECT TOP (1)
                tjd.AccountId
            FROM TransactionJournalDetail tjd
            WHERE tjd.TxId = st.TxId
              AND tjd.SourceDetailId = t.SalesDetailId
              AND tjd.AccountId IN (@ISALEAccountId, @ICREDITAccountId)
        ) oldSale
        WHERE t.EmpId = @EmpId
          AND t.IsChanged = 1;

        IF NOT EXISTS (SELECT 1 FROM #LineUpdates)
        BEGIN
            DELETE FROM TempBombSales
            WHERE EmpId = @EmpId;

            COMMIT TRANSACTION;
            RETURN;
        END;

        ---------------------------------------------------------------------
        -- 9. Update SalesDetail.
        --    This replaces the U branch SalesDetail update in Sales_PartialUpdate.
        ---------------------------------------------------------------------
        UPDATE sd
        SET
            sd.ItemId          = lu.NewItemId,
            sd.ItemUnitId      = lu.ItemUnitId,
            sd.Unit            = lu.Unit,
            sd.OrdQty          = lu.OrdQty,
            sd.ShipQty         = lu.ShipQty,
            sd.BillQty         = lu.BillQty,
            sd.UnitPrice       = lu.UnitPrice,
            sd.ExtTotal        = lu.ExtTotal,
            sd.Notes           = lu.Notes,
            sd.IsTaxable       = lu.IsTaxable,
            sd.OrgPrice        = lu.OrgPrice,
            sd.DiscountPercent = lu.DiscountPercent,
            sd.FactorToBase    = lu.FactorToBase,
            sd.BaseOrdQty      = lu.BaseOrdQty,
            sd.BaseShipQty     = lu.BaseShipQty,
            sd.BaseBillQty     = lu.BaseBillQty,
            sd.IsUserOverWrite = ISNULL(lu.IsUserOverWrite, 0)
                --CASE
                --    WHEN lu.IsUserOverWrite = 1 THEN 1
                --    ELSE sd.IsUserOverWrite
                --END
        FROM SalesDetail sd
        INNER JOIN #LineUpdates lu
            ON lu.SalesId = sd.SalesId
           AND lu.SalesDetailId = sd.SalesDetailId;

        ---------------------------------------------------------------------
        -- 10. Update existing sales / credit journal rows.
        --     This updates @ISALE or @ICREDIT depending on ExtTotal sign.
        --     Uses your inline TVF dbo.Fn_CrDeAmount.
        ---------------------------------------------------------------------
        UPDATE tjd
        SET
            tjd.Qty          = lu.BillQty,
            tjd.Price        = lu.UnitPrice,
            tjd.BillQty      = lu.ExtTotal,
            tjd.Amount       = lu.ExtTotal,
            tjd.CrDeAmount   = ca.CrDeAmount,
            tjd.ItemId       = lu.NewItemId,
            tjd.AccountId    = lu.NewSalesAccountId,
            tjd.FactorToBase = lu.FactorToBase
        FROM TransactionJournalDetail tjd
        INNER JOIN #LineUpdates lu
            ON lu.TxId = tjd.TxId
           AND lu.SalesDetailId = tjd.SourceDetailId
           AND lu.OldSalesAccountId = tjd.AccountId
        CROSS APPLY dbo.Fn_CrDeAmount
        (
            lu.NewSalesAccountCode,
            ABS(lu.ExtTotal)
        ) ca
        WHERE lu.OldSalesAccountId IS NOT NULL;

        ---------------------------------------------------------------------
        -- 11. Insert missing sales / credit journal rows.
        --     This protects against older/incomplete journal data.
        ---------------------------------------------------------------------
        INSERT INTO TransactionJournalDetail
        (
            TxId,
            AccountId,
            PayeeId,
            ItemId,
            Qty,
            Price,
            BillQty,
            Amount,
            CrDeAmount,
            SourceDetailId,
            FactorToBase
        )
        SELECT
            lu.TxId,
            lu.NewSalesAccountId,
            lu.PayeeId,
            lu.NewItemId,
            lu.BillQty,
            lu.UnitPrice,
            lu.ExtTotal,
            lu.ExtTotal,
            ca.CrDeAmount,
            lu.SalesDetailId,
            lu.FactorToBase
        FROM #LineUpdates lu
        CROSS APPLY dbo.Fn_CrDeAmount
        (
            lu.NewSalesAccountCode,
            ABS(lu.ExtTotal)
        ) ca
        WHERE lu.OldSalesAccountId IS NULL;

        ---------------------------------------------------------------------
        -- 12. Inventory item: update existing @COGS rows.
        ---------------------------------------------------------------------
        UPDATE tjd
        SET
            tjd.ItemId       = lu.NewItemId,
            tjd.FactorToBase = lu.FactorToBase
        FROM TransactionJournalDetail tjd
        INNER JOIN #LineUpdates lu
            ON lu.TxId = tjd.TxId
           AND lu.SalesDetailId = tjd.SourceDetailId
        WHERE lu.ItemType = 'Inventory'
          AND tjd.AccountId = @COGSAccountId;

        ---------------------------------------------------------------------
        -- 13. Inventory item: insert missing @COGS rows.
        ---------------------------------------------------------------------
        INSERT INTO TransactionJournalDetail
        (
            TxId,
            AccountId,
            PayeeId,
            ItemId,
            FactorToBase,
            SourceDetailId
        )
        SELECT
            lu.TxId,
            @COGSAccountId,
            lu.PayeeId,
            lu.NewItemId,
            lu.FactorToBase,
            lu.SalesDetailId
        FROM #LineUpdates lu
        WHERE lu.ItemType = 'Inventory'
          AND NOT EXISTS
          (
              SELECT 1
              FROM TransactionJournalDetail tjd
              WHERE tjd.TxId = lu.TxId
                AND tjd.SourceDetailId = lu.SalesDetailId
                AND tjd.AccountId = @COGSAccountId
          );

        ---------------------------------------------------------------------
        -- 14. Inventory item: update existing @INV rows.
        ---------------------------------------------------------------------
        UPDATE tjd
        SET
            tjd.Qty          = lu.BaseShipQty,
            tjd.Price        = lu.UnitPrice,
            tjd.BillQty      = lu.BaseBillQty,
            tjd.ItemId       = lu.NewItemId,
            tjd.FactorToBase = lu.FactorToBase
        FROM TransactionJournalDetail tjd
        INNER JOIN #LineUpdates lu
            ON lu.TxId = tjd.TxId
           AND lu.SalesDetailId = tjd.SourceDetailId
        WHERE lu.ItemType = 'Inventory'
          AND tjd.AccountId = @INVAccountId;

        ---------------------------------------------------------------------
        -- 15. Inventory item: insert missing @INV rows.
        ---------------------------------------------------------------------
        INSERT INTO TransactionJournalDetail
        (
            TxId,
            AccountId,
            PayeeId,
            ItemId,
            Qty,
            Price,
            BillQty,
            SourceDetailId,
            FactorToBase
        )
        SELECT
            lu.TxId,
            @INVAccountId,
            lu.PayeeId,
            lu.NewItemId,
            lu.BaseShipQty,
            lu.UnitPrice,
            lu.BaseBillQty,
            lu.SalesDetailId,
            lu.FactorToBase
        FROM #LineUpdates lu
        WHERE lu.ItemType = 'Inventory'
          AND NOT EXISTS
          (
              SELECT 1
              FROM TransactionJournalDetail tjd
              WHERE tjd.TxId = lu.TxId
                AND tjd.SourceDetailId = lu.SalesDetailId
                AND tjd.AccountId = @INVAccountId
          );

        ---------------------------------------------------------------------
        -- 16. If line is now non-inventory, remove old @COGS/@INV rows.
        --     This safely handles Inventory -> NonInventory item changes.
        ---------------------------------------------------------------------
        DELETE tjd
        FROM TransactionJournalDetail tjd
        INNER JOIN #LineUpdates lu
            ON lu.TxId = tjd.TxId
           AND lu.SalesDetailId = tjd.SourceDetailId
        WHERE ISNULL(lu.ItemType, '') <> 'Inventory'
          AND tjd.AccountId IN (@COGSAccountId, @INVAccountId);

        ---------------------------------------------------------------------
        -- 17. RecalculationLog for old item if item changed.
        ---------------------------------------------------------------------
        INSERT INTO RecalculationLog
        (
            ItemId,
            TxId,
            TxDate
        )
        SELECT DISTINCT
            lu.OldItemId,
            lu.TxId,
            lu.ShipDate
        FROM #LineUpdates lu
        WHERE lu.OldItemId IS NOT NULL
          AND ISNULL(lu.OldItemId, 0) <> ISNULL(lu.NewItemId, 0);

        ---------------------------------------------------------------------
        -- 18. RecalculationLog for changed new item rows.
        ---------------------------------------------------------------------
        INSERT INTO RecalculationLog
        (
            ItemId,
            TxId,
            TxDate
        )
        SELECT DISTINCT
            lu.NewItemId,
            lu.TxId,
            lu.ShipDate
        FROM #LineUpdates lu
        WHERE lu.NewItemId IS NOT NULL;

        ---------------------------------------------------------------------
        -- 19. Recalculate Sales totals for every affected SalesId.
        --     This is the core inline total logic from Sales_PartialUpdate.
        ---------------------------------------------------------------------
        INSERT INTO #SalesTotals
        (
            SalesId,
            SubTotal,
            TaxableTotal,
            TaxTotal,
            SalesTotal
        )
        SELECT
            s.SalesId,

            ISNULL(SUM(ROUND(sd.BillQty * sd.UnitPrice, 2)), 0) AS SubTotal,

            ISNULL(SUM(
                CASE
                    WHEN sd.IsTaxable = 1
                    THEN ROUND(sd.BillQty * sd.UnitPrice, 2)
                    ELSE 0
                END
            ), 0) AS TaxableTotal,

            ROUND(
                ISNULL(SUM(
                    CASE
                        WHEN sd.IsTaxable = 1
                        THEN ROUND(sd.BillQty * sd.UnitPrice, 2)
                        ELSE 0
                    END
                ), 0) * ISNULL(s.TaxPercent, 0),
                2
            ) AS TaxTotal,

            ISNULL(SUM(ROUND(sd.BillQty * sd.UnitPrice, 2)), 0)
            +
            ROUND(
                ISNULL(SUM(
                    CASE
                        WHEN sd.IsTaxable = 1
                        THEN ROUND(sd.BillQty * sd.UnitPrice, 2)
                        ELSE 0
                    END
                ), 0) * ISNULL(s.TaxPercent, 0),
                2
            ) AS SalesTotal
        FROM Sales s
        INNER JOIN #ChangedSales cs
            ON cs.SalesId = s.SalesId
        LEFT JOIN SalesDetail sd
            ON sd.SalesId = s.SalesId
        GROUP BY
            s.SalesId,
            s.TaxPercent;

        UPDATE s
        SET
            s.SubTotal     = st.SubTotal,
            s.TaxableTotal = st.TaxableTotal,
            s.TaxTotal     = st.TaxTotal,
            s.SalesTotal   = st.SalesTotal,
            s.Updateby     = @EmpId,
            s.UpdatedAt    = GETUTCDATE()
        FROM Sales s
        INNER JOIN #SalesTotals st
            ON st.SalesId = s.SalesId;

        ---------------------------------------------------------------------
        -- 20. Refresh base qty for all affected SalesDetail rows.
        ---------------------------------------------------------------------
        -- 2026-07-05 (Phase B): base qty from ItemUnitId -> ItemUnit (source of truth) via Fn_QtyToBase.
        -- INNER JOIN ItemUnit = item lines only; account lines (no ItemUnitId) keep base qty untouched.
        -- Stored-column refresh only (runs after the @INV updates). Prior:
        -- UPDATE sd
        -- SET
        --     sd.BaseOrdQty  = ROUND(sd.OrdQty  / NULLIF(sd.FactorToBase, 0), 6),
        --     sd.BaseShipQty = ROUND(sd.ShipQty / NULLIF(sd.FactorToBase, 0), 6),
        --     sd.BaseBillQty = ROUND(sd.BillQty / NULLIF(sd.FactorToBase, 0), 6)
        -- FROM SalesDetail sd
        -- INNER JOIN #ChangedSales cs ON cs.SalesId = sd.SalesId;
        UPDATE sd
        SET
            sd.BaseOrdQty  = dbo.Fn_QtyToBase(sd.OrdQty,  iu.MultipleToBase, iu.FactorToBase),
            sd.BaseShipQty = dbo.Fn_QtyToBase(sd.ShipQty, iu.MultipleToBase, iu.FactorToBase),
            sd.BaseBillQty = dbo.Fn_QtyToBase(sd.BillQty, iu.MultipleToBase, iu.FactorToBase)
        FROM SalesDetail sd
        INNER JOIN #ChangedSales cs
            ON cs.SalesId = sd.SalesId
        INNER JOIN ItemUnit iu
            ON iu.ItemUnitId = sd.ItemUnitId;

        ---------------------------------------------------------------------
        -- 21. Refresh @AR journal rows.
        ---------------------------------------------------------------------
        UPDATE tjd
        SET
            tjd.Amount     = stot.SalesTotal,
            tjd.CrDeAmount = ca.CrDeAmount
        FROM TransactionJournalDetail tjd
        INNER JOIN #SalesTx stx
            ON stx.TxId = tjd.TxId
        INNER JOIN #SalesTotals stot
            ON stot.SalesId = stx.SalesId
        CROSS APPLY dbo.Fn_CrDeAmount
        (
            '@AR',
            stot.SalesTotal
        ) ca
        WHERE tjd.AccountId = @ARAccountId;

        ---------------------------------------------------------------------
        -- 22. Refresh existing sales tax journal rows.
        ---------------------------------------------------------------------
        UPDATE tjd
        SET
            tjd.Amount     = stot.TaxTotal,
            tjd.CrDeAmount = ca.CrDeAmount
        FROM TransactionJournalDetail tjd
        INNER JOIN #SalesTx stx
            ON stx.TxId = tjd.TxId
        INNER JOIN #SalesTotals stot
            ON stot.SalesId = stx.SalesId
        CROSS APPLY dbo.Fn_CrDeAmount
        (
            '@FSTP',
            stot.TaxTotal
        ) ca
        WHERE tjd.AccountId = @FSTPAccountId
          AND stot.TaxTotal <> 0;

        ---------------------------------------------------------------------
        -- 23. Insert missing sales tax journal rows.
        ---------------------------------------------------------------------
        INSERT INTO TransactionJournalDetail
        (
            TxId,
            AccountId,
            Amount,
            CrDeAmount
        )
        SELECT
            stx.TxId,
            @FSTPAccountId,
            stot.TaxTotal,
            ca.CrDeAmount
        FROM #SalesTx stx
        INNER JOIN #SalesTotals stot
            ON stot.SalesId = stx.SalesId
        CROSS APPLY dbo.Fn_CrDeAmount
        (
            '@FSTP',
            stot.TaxTotal
        ) ca
        WHERE stot.TaxTotal <> 0
          AND NOT EXISTS
          (
              SELECT 1
              FROM TransactionJournalDetail tjd
              WHERE tjd.TxId = stx.TxId
                AND tjd.AccountId = @FSTPAccountId
          );

        ---------------------------------------------------------------------
        -- 24. Delete sales tax journal rows if tax total is now zero.
        ---------------------------------------------------------------------
        DELETE tjd
        FROM TransactionJournalDetail tjd
        INNER JOIN #SalesTx stx
            ON stx.TxId = tjd.TxId
        INNER JOIN #SalesTotals stot
            ON stot.SalesId = stx.SalesId
        WHERE tjd.AccountId = @FSTPAccountId
          AND stot.TaxTotal = 0;

        ---------------------------------------------------------------------
        -- 25. Delete processed TempBombSales rows for this employee.
        --     Important: no TempSales delete here.
        ---------------------------------------------------------------------
        DELETE t
        FROM TempBombSales t
        INNER JOIN #ChangedSales cs
            ON cs.SalesId = t.SalesId
        WHERE t.EmpId = @EmpId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;

    -------------------------------------------------------------------------
    -- 26. Run Sales_CalcTotal after COMMIT.
    -------------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#CalcQueue') IS NOT NULL
        DROP TABLE #CalcQueue;

    CREATE TABLE #CalcQueue
    (
        RowId INT IDENTITY(1,1) PRIMARY KEY,
        SalesId INT NOT NULL
    );

    INSERT INTO #CalcQueue (SalesId)
    SELECT SalesId
    FROM #ChangedSales
    ORDER BY SalesId;

    DECLARE
        @CalcRowId INT = 1,
        @CalcMaxRowId INT,
        @CalcSalesId INT;

    SELECT @CalcMaxRowId = MAX(RowId)
    FROM #CalcQueue;

    WHILE @CalcRowId <= ISNULL(@CalcMaxRowId, 0)
    BEGIN
        SELECT @CalcSalesId = SalesId
        FROM #CalcQueue
        WHERE RowId = @CalcRowId;

        EXEC Sales_CalcTotal @CalcSalesId;

        SET @CalcRowId += 1;
    END;

END;


GO
