-- ============================================================
-- Shipment_ValidateAllocation — DRAFT v2 (post-review)
-- Phase 2: Pre-allocation data completeness check
-- ============================================================
-- Returns 2 result sets:
--   1. Method summary: coverage per allocation method
--   2. Missing data detail: which items lack data per method
--
-- Used by:
--   - Reallocate dialog (show coverage per method)
--   - Post-allocation report (identify fallback items)
--   - Convert to Bill flow (check before auto-allocate)
--
-- NOTE:
-- BY_VALUE and BY_DUTY/BY_TARIFF validate against FinalQty * FinalPrice
-- (both in entered unit, always consistent regardless of base unit conversion).
--
-- BY_VOLUME validates PurchaseDetail.ItemVolume (bill snapshot)
-- because Shipment_Allocation allocates from bill snapshot volume,
-- not directly from Item.CaseVolumeInCubicMeter. Use @RefreshVolume
-- to sync before allocation if needed.
--
-- Coverage is at whole-purchase level (all inventory lines for the
-- bill), not per-shipment or per-charge. If a purchase is attached
-- to multiple shipments, coverage shown applies to all charges.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[Shipment_ValidateAllocation]
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Collect all inventory item lines for this purchase
    IF OBJECT_ID('tempdb..#Check') IS NOT NULL DROP TABLE #Check;

    SELECT
        pd.PurchaseDetailId,
        pd.ItemId,
        i.ItemCode,
        i.ItemName,

        -- BY_VOLUME: uses bill snapshot ItemVolume (refreshable via @RefreshVolume)
        HasVolume = CASE
            WHEN ISNULL(pd.BaseFinalQty, 0) * ISNULL(pd.ItemVolume, 0) > 0
            THEN 1 ELSE 0
        END,

        -- BY_WEIGHT: uses Item master CaseWeight (always fresh)
        HasWeight = CASE
            WHEN ISNULL(pd.BaseFinalQty, 0) * ISNULL(i.CaseWeight, 0) > 0
            THEN 1 ELSE 0
        END,

        -- BY_PALLET: uses Item master PaletteFactor (always fresh)
        HasPallet = CASE
            WHEN ISNULL(i.PaletteFactor, 0) > 0
             AND ISNULL(pd.BaseFinalQty, 0) > 0
            THEN 1 ELSE 0
        END,

        -- BY_QUANTITY: just needs qty
        HasQty = CASE
            WHEN ISNULL(pd.BaseFinalQty, 0) > 0
            THEN 1 ELSE 0
        END,

        -- BY_VALUE: uses FinalQty * FinalPrice (both in entered unit, always consistent)
        HasValue = CASE
            WHEN ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0) > 0
            THEN 1 ELSE 0
        END,

        -- BY_DUTY / BY_TARIFF: full basis = FinalQty * FinalPrice * (DutyRate + TariffRate)
        HasDuty = CASE
            WHEN (ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0))
                 * (ISNULL(pd.CustomDutyRate, 0) + ISNULL(pd.TariffPercent, 0)) > 0
            THEN 1 ELSE 0
        END

    INTO #Check
    FROM dbo.PurchaseDetail pd
    JOIN dbo.Item i ON pd.ItemId = i.ItemId
    WHERE pd.PurchaseId = @PurchaseId
      AND pd.ItemId IS NOT NULL
      AND i.ItemType = 'Inventory';

    DECLARE @Total INT;
    SELECT @Total = COUNT(*) FROM #Check;

    -- If no items, return empty result sets with correct schema
    IF @Total = 0
    BEGIN
        SELECT
            Method        = CAST('' AS VARCHAR(20)),
            TotalItems    = 0,
            ItemsWithData = 0,
            ItemsMissing  = 0,
            Coverage      = 0
        WHERE 1 = 0;

        SELECT
            Method       = CAST('' AS VARCHAR(20)),
            ItemId       = 0,
            ItemCode     = CAST('' AS VARCHAR(50)),
            ItemName     = CAST('' AS VARCHAR(255)),
            MissingField = CAST('' AS VARCHAR(100))
        WHERE 1 = 0;

        RETURN;
    END

    -- ============================================================
    -- Result Set 1: Method summary (one row per method)
    -- ============================================================
    SELECT Method, TotalItems, ItemsWithData, ItemsMissing, Coverage
    FROM (
        SELECT
            Method        = 'BY_VOLUME',
            TotalItems    = @Total,
            ItemsWithData = SUM(HasVolume),
            ItemsMissing  = @Total - SUM(HasVolume),
            Coverage      = CAST(SUM(HasVolume) * 100 / @Total AS INT)
        FROM #Check

        UNION ALL

        SELECT
            'BY_WEIGHT',
            @Total,
            SUM(HasWeight),
            @Total - SUM(HasWeight),
            CAST(SUM(HasWeight) * 100 / @Total AS INT)
        FROM #Check

        UNION ALL

        SELECT
            'BY_PALLET',
            @Total,
            SUM(HasPallet),
            @Total - SUM(HasPallet),
            CAST(SUM(HasPallet) * 100 / @Total AS INT)
        FROM #Check

        UNION ALL

        SELECT
            'BY_QUANTITY',
            @Total,
            SUM(HasQty),
            @Total - SUM(HasQty),
            CAST(SUM(HasQty) * 100 / @Total AS INT)
        FROM #Check

        UNION ALL

        SELECT
            'BY_VALUE',
            @Total,
            SUM(HasValue),
            @Total - SUM(HasValue),
            CAST(SUM(HasValue) * 100 / @Total AS INT)
        FROM #Check

        UNION ALL

        SELECT
            'BY_DUTY',
            @Total,
            SUM(HasDuty),
            @Total - SUM(HasDuty),
            CAST(SUM(HasDuty) * 100 / @Total AS INT)
        FROM #Check

        UNION ALL

        SELECT
            'BY_TARIFF',
            @Total,
            SUM(HasDuty),
            @Total - SUM(HasDuty),
            CAST(SUM(HasDuty) * 100 / @Total AS INT)
        FROM #Check
    ) AS Summary
    ORDER BY
        CASE Method
            WHEN 'BY_VOLUME'   THEN 1
            WHEN 'BY_WEIGHT'   THEN 2
            WHEN 'BY_PALLET'   THEN 3
            WHEN 'BY_QUANTITY'  THEN 4
            WHEN 'BY_VALUE'    THEN 5
            WHEN 'BY_DUTY'     THEN 6
            WHEN 'BY_TARIFF'   THEN 7
        END;

    -- ============================================================
    -- Result Set 2: Missing data detail (one row per item per method)
    -- Only includes methods with missing items.
    -- BY_DUTY and BY_TARIFF share the same basis so both appear
    -- if missing — intentional for UI consistency with method list.
    -- ============================================================
    SELECT Method, ItemId, ItemCode, ItemName, MissingField
    FROM (
        SELECT
            Method       = 'BY_VOLUME',
            ItemId,
            ItemCode,
            ItemName,
            MissingField = 'ItemVolume'
        FROM #Check
        WHERE HasVolume = 0

        UNION ALL

        SELECT
            'BY_WEIGHT',
            ItemId,
            ItemCode,
            ItemName,
            'CaseWeight'
        FROM #Check
        WHERE HasWeight = 0

        UNION ALL

        SELECT
            'BY_PALLET',
            ItemId,
            ItemCode,
            ItemName,
            'PaletteFactor'
        FROM #Check
        WHERE HasPallet = 0

        UNION ALL

        SELECT
            'BY_QUANTITY',
            ItemId,
            ItemCode,
            ItemName,
            'BaseFinalQty'
        FROM #Check
        WHERE HasQty = 0

        UNION ALL

        SELECT
            'BY_VALUE',
            ItemId,
            ItemCode,
            ItemName,
            'FinalQty * FinalPrice'
        FROM #Check
        WHERE HasValue = 0

        UNION ALL

        SELECT
            'BY_DUTY',
            ItemId,
            ItemCode,
            ItemName,
            'DutyWeight (Qty * Price * Rate)'
        FROM #Check
        WHERE HasDuty = 0

        UNION ALL

        SELECT
            'BY_TARIFF',
            ItemId,
            ItemCode,
            ItemName,
            'DutyWeight (Qty * Price * Rate)'
        FROM #Check
        WHERE HasDuty = 0
    ) AS Detail
    ORDER BY Method, ItemCode;
END
GO
