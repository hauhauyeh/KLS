SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP PROCEDURE IF EXISTS [dbo].[_exam_itemunitid_verify]
GO
-- =============================================================================
-- _exam_itemunitid_verify   (utility / detection SP -- read-only)
-- Verifies "ItemUnitId is the source of truth" holds across the three truths of a
-- sales line, for sales on/after the system upgrade (default 2026-05-04).
--
--   Entered Truth   = sd.ShipQty         -- qty as keyed, in the line's unit
--   Converted Truth = sd.BaseShipQty     -- base qty; SHOULD equal the ItemUnitId ratio
--                     applied to ShipQty: ROUND(ShipQty * MultipleToBase / FactorToBase, 6)
--   Book Truth      = @INV TxDetail.Qty   -- what actually posted to inventory (the ledger)
--
-- Healthy line: Converted(from ItemUnitId) == stored BaseShipQty == Book, in MAGNITUDE.
--
-- Two hard-won guards (both proved necessary while auditing this data):
--   * SIGN ignored -- returns/credits key negative ShipQty and the @INV row posts the
--     opposite sign; comparing magnitudes verifies the RATIO, not the direction.
--   * ROUNDING-aware -- a mismatch counts only if it exceeds BOTH 0.01 absolute AND 5%
--     relative, so 2-decimal historical @INV postings (2/12 posted 0.17 vs exact 0.166667)
--     are NOT flagged. Only a real ratio break (a mutated/crossed unit ratio) surfaces.
-- =============================================================================
CREATE PROCEDURE [dbo].[_exam_itemunitid_verify] -- EXEC _exam_itemunitid_verify
-- EXEC _exam_itemunitid_verify @FromDate='2026-05-04'
-- EXEC _exam_itemunitid_verify @FromDate='2026-05-04', @ShowRows=0
    @FromDate DATE = '2026-05-04',   -- exam sales on/after the upgrade (ItemUnitId = source of truth)
    @ShowRows BIT  = 1               -- 1 = also return the offending rows; 0 = summary only
AS
BEGIN
    SET NOCOUNT ON;

    -- Book Truth: net posted @INV base qty per line (SUM handles multi-row / adjustments).
    ;WITH book AS (
        SELECT tjd.SourceDetailId AS SalesDetailId, book_qty = SUM(tjd.Qty)
        FROM TransactionJournalDetail tjd
        JOIN Account a ON a.AccountId = tjd.AccountId
        WHERE a.AccountCode = '@INV'
        GROUP BY tjd.SourceDetailId
    ),
    -- The three truths, side by side, per inventory-capable item line.
    chk AS (
        SELECT
            sd.SalesDetailId, sd.SalesId, i.ItemCode, i.ItemType, s.ShipDate,
            sd.ItemUnitId, iu.Unit, iu.FactorToBase, iu.MultipleToBase,
            entered       = sd.ShipQty,                                                      -- Entered
            conv_stored   = sd.BaseShipQty,                                                  -- Converted (stored)
            conv_expected = ROUND(sd.ShipQty * iu.MultipleToBase / NULLIF(iu.FactorToBase, 0), 6), -- Converted (from ItemUnitId)
            book          = b.book_qty                                                       -- Book
        FROM SalesDetail sd
        JOIN ItemUnit iu ON iu.ItemUnitId = sd.ItemUnitId
        JOIN Item i ON i.ItemId = sd.ItemId
        JOIN Sales s ON s.SalesId = sd.SalesId
        LEFT JOIN book b ON b.SalesDetailId = sd.SalesDetailId
        WHERE sd.LineType = 'I'
          AND sd.ItemId IS NOT NULL
          AND sd.ShipQty <> 0
          AND s.ShipDate >= @FromDate
    ),
    flagged AS (
        SELECT *,
            -- Entered -> Converted link: stored BaseShipQty vs the live ItemUnitId ratio
            base_break = CASE WHEN ABS(ABS(conv_stored) - ABS(conv_expected)) > 0.01
                              AND  ABS(ABS(conv_stored) - ABS(conv_expected)) > 0.05 * ABS(NULLIF(conv_expected,0))
                              THEN 1 ELSE 0 END,
            -- Converted -> Book link: @INV ledger vs the live ItemUnitId ratio (only where an @INV row exists)
            book_break = CASE WHEN book IS NULL THEN 0
                              WHEN ABS(ABS(book) - ABS(conv_expected)) > 0.01
                              AND  ABS(ABS(book) - ABS(conv_expected)) > 0.05 * ABS(NULLIF(conv_expected,0))
                              THEN 1 ELSE 0 END,
            base_missing = CASE WHEN conv_stored IS NULL THEN 1 ELSE 0 END,
            book_missing = CASE WHEN ItemType = 'Inventory' AND book IS NULL THEN 1 ELSE 0 END
        FROM chk
    )
    -- (1) summary
    SELECT
        from_date        = @FromDate,
        lines_examined   = COUNT(*),
        clean            = SUM(CASE WHEN base_break=0 AND book_break=0 AND base_missing=0 AND book_missing=0 THEN 1 ELSE 0 END),
        base_ratio_break = SUM(base_break),   -- stored BaseShipQty disagrees with ItemUnitId ratio
        book_ratio_break = SUM(book_break),   -- @INV ledger disagrees with ItemUnitId ratio
        base_qty_missing = SUM(base_missing), -- BaseShipQty NULL on an item line
        inv_row_missing  = SUM(book_missing)  -- Inventory item with no @INV row
    FROM flagged;

    -- (2) the offending rows
    IF @ShowRows = 1
        SELECT SalesDetailId, SalesId, ItemCode, ItemType, ShipDate,
               ItemUnitId, Unit, FactorToBase, MultipleToBase,
               entered, conv_stored, conv_expected, book,
               issue = CASE WHEN base_break=1 AND book_break=1 THEN 'BASE+BOOK ratio break'
                            WHEN base_break=1 THEN 'BASE ratio break (stored <> ItemUnit)'
                            WHEN book_break=1 THEN 'BOOK ratio break (ledger <> ItemUnit)'
                            WHEN base_missing=1 THEN 'BaseShipQty NULL'
                            WHEN book_missing=1 THEN '@INV row missing (Inventory)' END
        FROM flagged
        WHERE base_break=1 OR book_break=1 OR base_missing=1 OR book_missing=1
        ORDER BY ShipDate DESC, ItemCode;
END
GO
