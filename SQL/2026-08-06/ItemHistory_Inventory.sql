-- =============================================================================
-- ItemHistory_Inventory -- deploy (CREATE OR ALTER). Working file per SP workflow.
-- Feeds the item-list 'v' modal (Inventory History).
-- 2026-08-06: expose Sales.SalesDocNumber for Sales inventory rows so the UI can
--   honor SALES_DOC_NUMBER_DISPLAY_ENABLED while keeping SourceDocNumber as fallback.
-- 2026-07-03: remove the journal FactorToBase dependency (Phase D prep -- "migrate
--   ItemHistory_Inventory FTB to source before dropping journal FactorToBase").
--   FactorToBase (td.FactorToBase, the TransactionJournalDetail snapshot) was read
--   ONLY to size the mismatch tolerance: ABS(ClosingQty - ExpectedQty) > (1.0/FTB).
--   ClosingQty/ExpectedQty are BASE-unit on-hand and IsMismatch is a diagnostic flag,
--   so the tolerance is now a FIXED base-unit constant -- no journal factor, and not
--   re-derived from SalesDetail.FactorToBase either (which would just move the reader).
-- Behavior note: base-unit items (old FTB=1) are UNCHANGED (tol was 1.0, still 1.0).
--   Pack items (old FTB>1) had a tighter tol (e.g. 0.1); now 1.0 -> slightly looser.
--   Tune @MismatchTolerance below if you want to catch sub-unit drift.
-- Baseline: KLS/SQL/2026-08-06/ItemHistory_Inventory_live_baseline.sql
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[ItemHistory_Inventory] -- EXEC ItemHistory_Inventory @ItemId=1377
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 2026-07-03: fixed base-unit mismatch tolerance (replaces the old 1.0/FTB, which
    -- read the journal FactorToBase). 1.0 = one base unit of drift; lower it (e.g. 0.01)
    -- to flag sub-unit discrepancies.
    DECLARE @MismatchTolerance DECIMAL(18,6) = 1.0;

    ;WITH history AS (
        SELECT
            td.TxDetailId,
            t.TxId,
            t.TxDate,
            t.SourceDocType,
            t.SourceDocNumber,
            s.SalesDocNumber,
            t.SourceDocOrder,
            CASE WHEN t.SourceDocType = 'Sales' THEN td.Qty * -1 ELSE td.Qty END AS InventoryQty,
            td.Qty AS RawQty,
            td.Price,
            td.ClosingQty,
            td.AverageCost,
            -- 2026-07-03: FTB retired (journal FactorToBase dependency; Phase D). Prior line:
            -- ISNULL(NULLIF(td.FactorToBase, 0), 1) AS FTB,
            LAG(td.ClosingQty) OVER (
                ORDER BY t.TxDate, t.SourceDocOrder, td.TxDetailId
            ) AS PrevQty
        FROM TransactionJournal AS t
        INNER JOIN TransactionJournalDetail AS td ON t.TxId = td.TxId
        INNER JOIN Account AS a ON a.AccountId = td.AccountId
        LEFT JOIN Sales AS s ON t.SourceDocType = 'Sales'
            AND s.SalesNumber = t.SourceDocNumber
        WHERE td.ItemId = @ItemId AND a.AccountCode = '@INV'
    ),
    calc AS (
        SELECT h.*,
            CASE
                -- Purchase
                WHEN SourceDocOrder IN (300,305,310,320,680,685)
                    THEN PrevQty + RawQty

                -- Sales
                WHEN SourceDocOrder IN (500,505)
                    THEN PrevQty - RawQty

                -- OBE / General Journal (absolute)
                WHEN SourceDocOrder = 100
                    THEN RawQty

                -- Inventory Adj
                WHEN SourceDocOrder IN (600,695) THEN
                    CASE ia.AdjType
                        WHEN 'Q' THEN RawQty
                        WHEN 'B' THEN RawQty
                        WHEN 'V' THEN PrevQty
                        WHEN 'C' THEN PrevQty + RawQty
                        ELSE h.ClosingQty
                    END

                ELSE PrevQty + RawQty
            END AS ExpectedQty
        FROM history h
        LEFT JOIN InventoryAdj ia ON h.SourceDocOrder IN (600,695)
            AND ia.AdjNumber = h.SourceDocNumber
    )
    SELECT TOP(300)
        TxDetailId,
        TxId,
        TxDate,
        SourceDocType,
        SourceDocNumber,
        SalesDocNumber,
        InventoryQty,
        Price,
        ClosingQty,
        AverageCost,
        CASE
            WHEN PrevQty IS NULL THEN CAST(0 AS BIT)
            -- 2026-07-03: fixed base-unit tolerance replaces the journal-factor one. Prior line:
            -- WHEN ABS(ClosingQty - ExpectedQty) > (1.0 / FTB) THEN CAST(1 AS BIT)
            WHEN ABS(ClosingQty - ExpectedQty) > @MismatchTolerance THEN CAST(1 AS BIT)
            ELSE CAST(0 AS BIT)
        END AS IsMismatch
    FROM calc
    ORDER BY TxDate DESC, SourceDocOrder DESC, TxDetailId DESC
END
GO
