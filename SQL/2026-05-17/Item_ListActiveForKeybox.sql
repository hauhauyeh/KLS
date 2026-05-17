-- ============================================================================
-- Item_ListActiveForKeybox — add vendor mode
-- Round: 2026-05-17
--
-- @Mode = 'customer' (default) — body byte-for-byte from live baseline.
-- @Mode = 'vendor'             — same CandidateItems, LastOrder pivots to
--                                 Purchase tables filtered by PayeeId.
--
-- First-time modification: rename live SP to _prev as the rollback baseline,
-- then DROP + CREATE the new version.
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Item_ListActiveForKeybox')
   AND NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Item_ListActiveForKeybox_prev')
    EXEC sp_rename 'Item_ListActiveForKeybox', 'Item_ListActiveForKeybox_prev';
GO

DROP PROCEDURE IF EXISTS dbo.Item_ListActiveForKeybox;
GO

CREATE PROCEDURE [dbo].[Item_ListActiveForKeybox]
    @PayeeId INT,
    @Mode    NVARCHAR(10) = 'customer'   -- 'customer' | 'vendor'
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode NOT IN ('customer', 'vendor')
        THROW 50030, 'Invalid @Mode. Use ''customer'' or ''vendor''.', 1;

    IF @Mode = 'customer'
    BEGIN
        /*
        Baseline before candidate-item confinement:

        ;WITH LastOrder AS (
            SELECT
                sd.ItemId,
                s.ShipDate AS LastOrderDate,
                sd.OrdQty AS LastOrderQty,
                sd.Unit AS LastOrderUnit,
                ROW_NUMBER() OVER (PARTITION BY sd.ItemId ORDER BY s.SalesId DESC) AS rn
            FROM SalesDetail sd
            INNER JOIN Sales s ON sd.SalesId = s.SalesId
            WHERE s.ShipId = @PayeeId
        )
        SELECT TOP (500)
            i.ItemId, i.ItemCode, i.ItemName,
            bu.Unit AS BaseUnit, i.LCloseQty, i.Inactive, i.ItemSearchTag,
            lo.LastOrderDate, lo.LastOrderQty, lo.LastOrderUnit
        FROM Item i
        LEFT JOIN ItemUnit bu ON i.ItemId = bu.ItemId AND bu.IsBaseUnit = 1 AND bu.Inactive = 0
        LEFT JOIN LastOrder lo ON i.ItemId = lo.ItemId AND lo.rn = 1
        WHERE i.IsDeleted = 0 AND i.Inactive = 0
        ORDER BY i.Last3M DESC;
        */

        ;WITH CandidateItems AS (
            SELECT
                i.ItemId,
                i.ItemCode,
                i.ItemName,
                i.LCloseQty,
                i.Inactive,
                i.ItemSearchTag,
                i.Last3M
            FROM Item i
            WHERE i.IsDeleted = 0
              AND i.Inactive = 0
              AND ISNULL(i.Last3M, 0) > 0
        ),
        LastOrder AS (
            SELECT
                sd.ItemId,
                s.ShipDate AS LastOrderDate,
                sd.OrdQty AS LastOrderQty,
                sd.Unit AS LastOrderUnit,
                ROW_NUMBER() OVER (PARTITION BY sd.ItemId ORDER BY s.SalesId DESC) AS rn
            FROM CandidateItems ci
            INNER JOIN SalesDetail sd ON ci.ItemId = sd.ItemId
            INNER JOIN Sales s ON sd.SalesId = s.SalesId
            WHERE s.ShipId = @PayeeId
        )
        SELECT
            ci.ItemId, ci.ItemCode, ci.ItemName,
            bu.Unit AS BaseUnit, ci.LCloseQty, ci.Inactive, ci.ItemSearchTag,
            lo.LastOrderDate, lo.LastOrderQty, lo.LastOrderUnit,
            null AS PrimaryImageUrl
        FROM CandidateItems ci
        LEFT JOIN ItemUnit bu ON ci.ItemId = bu.ItemId AND bu.IsBaseUnit = 1 AND bu.Inactive = 0
        LEFT JOIN LastOrder lo ON ci.ItemId = lo.ItemId AND lo.rn = 1
        ORDER BY ci.Last3M DESC;
    END
    ELSE  -- @Mode = 'vendor'
    BEGIN
        -- Vendor mode: same CandidateItems pool as customer.
        -- LastOrder pivots to Purchase tables filtered by Purchase.PayeeId.
        -- Uses pd.OrdQty0 (analog of SalesDetail.OrdQty) — there is no
        -- plain "OrdQty" column on PurchaseDetail.
        ;WITH CandidateItems AS (
            SELECT
                i.ItemId,
                i.ItemCode,
                i.ItemName,
                i.LCloseQty,
                i.Inactive,
                i.ItemSearchTag,
                i.Last3M
            FROM Item i
            WHERE i.IsDeleted = 0
              AND i.Inactive = 0
              AND ISNULL(i.Last3M, 0) > 0
        ),
        LastOrder AS (
            SELECT
                pd.ItemId,
                p.PurchaseDate AS LastOrderDate,
                pd.OrdQty0     AS LastOrderQty,
                pd.Unit        AS LastOrderUnit,
                ROW_NUMBER() OVER (PARTITION BY pd.ItemId ORDER BY p.PurchaseId DESC) AS rn
            FROM CandidateItems ci
            INNER JOIN PurchaseDetail pd ON ci.ItemId = pd.ItemId
            INNER JOIN Purchase p ON pd.PurchaseId = p.PurchaseId
            WHERE p.PayeeId = @PayeeId
        )
        SELECT
            ci.ItemId, ci.ItemCode, ci.ItemName,
            bu.Unit AS BaseUnit, ci.LCloseQty, ci.Inactive, ci.ItemSearchTag,
            lo.LastOrderDate, lo.LastOrderQty, lo.LastOrderUnit,
            null AS PrimaryImageUrl
        FROM CandidateItems ci
        LEFT JOIN ItemUnit bu ON ci.ItemId = bu.ItemId AND bu.IsBaseUnit = 1 AND bu.Inactive = 0
        LEFT JOIN LastOrder lo ON ci.ItemId = lo.ItemId AND lo.rn = 1
        ORDER BY ci.Last3M DESC;
    END
END
GO
