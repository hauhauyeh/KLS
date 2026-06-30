SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- 2026-06-29 (Plan 1 — shipment-allocation-completeness-guard):
--   Two changes so the UI coverage report matches the allocation guard exactly:
--   (1) ATTRIBUTE-PRESENCE checks. Completeness now tests the master-data attribute itself
--       (ItemVolume>0, CaseWeight>0, CustomDutyRate+TariffPercent>0) instead of the qty/value-scaled
--       product. This matches Shipment_Allocation's all-or-nothing guard and stops a legitimate free
--       line (price 0) from being falsely reported as "missing".
--   (2) Optional @ShipmentId. The guard allocates at SHIPMENT scope, so validation must be able to
--       answer at shipment scope. @ShipmentId supplied => check every inventory line of every bill in
--       that shipment; @ShipmentId NULL => bill-scoped by @PurchaseId (today's behavior, backward
--       compatible — the existing ValidateAllocation/{purchaseId} caller is unaffected).
--   Parity rule: ItemsMissing(M)=0 at @ShipmentId scope  <=>  the guard honors method M.
-- =============================================================================================

DROP PROCEDURE IF EXISTS [dbo].[Shipment_ValidateAllocation]
GO

CREATE PROCEDURE [dbo].[Shipment_ValidateAllocation] -- EXEC Shipment_ValidateAllocation @PurchaseId=12164
-- EXEC Shipment_ValidateAllocation @ShipmentId=7
    -- 2026-06-29: @PurchaseId made optional and @ShipmentId added (one of the two drives the scope).
    -- removed: @PurchaseId INT
    @PurchaseId INT = NULL,
    @ShipmentId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#Check') IS NOT NULL DROP TABLE #Check;

    SELECT
        pd.PurchaseDetailId,
        -- 2026-06-29: attribute-presence (was qty/value-scaled). Old versions kept for reference:
        -- HasVolume = CASE WHEN ISNULL(pd.BaseFinalQty, 0) * ISNULL(pd.ItemVolume, 0) > 0 THEN 1 ELSE 0 END,
        -- HasWeight = CASE WHEN ISNULL(pd.BaseFinalQty, 0) * ISNULL(i.CaseWeight, 0) > 0 THEN 1 ELSE 0 END,
        HasVolume = CASE WHEN ISNULL(pd.ItemVolume, 0) > 0 THEN 1 ELSE 0 END,
        HasWeight = CASE WHEN ISNULL(i.CaseWeight, 0) > 0 THEN 1 ELSE 0 END,
        HasQty    = CASE WHEN ISNULL(pd.BaseFinalQty, 0) > 0 THEN 1 ELSE 0 END,
        HasValue  = CASE WHEN ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0) > 0 THEN 1 ELSE 0 END,
        -- 2026-06-29: duty completeness = combined rate present (was value*rate>0). A free line with a
        -- rate set is "complete"; a priced line without a rate is "missing".
        -- HasDuty = CASE WHEN (ISNULL(pd.FinalQty,0)*ISNULL(pd.FinalPrice,0)) * (ISNULL(pd.CustomDutyRate,0)+ISNULL(pd.TariffPercent,0)) > 0 THEN 1 ELSE 0 END
        HasDuty   = CASE
                        WHEN (ISNULL(pd.CustomDutyRate, 0) + ISNULL(pd.TariffPercent, 0)) > 0
                        THEN 1 ELSE 0
                    END
    INTO #Check
    FROM dbo.PurchaseDetail pd
    JOIN dbo.Item i ON pd.ItemId = i.ItemId
    WHERE pd.ItemId IS NOT NULL
      AND i.ItemType = 'Inventory'
      -- 2026-06-29: scope selector. @ShipmentId wins when supplied (shipment scope = the guard's
      -- scope, all bills in the shipment); otherwise bill scope by @PurchaseId (preview, legacy).
      AND (
            (@ShipmentId IS NOT NULL
                 AND pd.PurchaseId IN (SELECT sp.PurchaseId FROM dbo.ShipmentPurchase sp WHERE sp.ShipmentId = @ShipmentId))
         OR (@ShipmentId IS NULL
                 AND pd.PurchaseId = @PurchaseId)
          );

    DECLARE @Total INT;
    SELECT @Total = COUNT(*) FROM #Check;

    IF @Total = 0
    BEGIN
        SELECT
            Method        = CAST('' AS VARCHAR(20)),
            TotalItems    = 0,
            ItemsWithData = 0,
            ItemsMissing  = 0,
            Coverage      = 0
        WHERE 1 = 0;
        RETURN;
    END

    SELECT Method, TotalItems, ItemsWithData, ItemsMissing, Coverage
    FROM (
        SELECT 'BY_VOLUME'  AS Method, @Total AS TotalItems, SUM(HasVolume) AS ItemsWithData, @Total - SUM(HasVolume) AS ItemsMissing, CAST(SUM(HasVolume) * 100 / @Total AS INT) AS Coverage FROM #Check
        UNION ALL
        SELECT 'BY_WEIGHT',  @Total, SUM(HasWeight), @Total - SUM(HasWeight), CAST(SUM(HasWeight) * 100 / @Total AS INT) FROM #Check
        UNION ALL
        SELECT 'BY_QUANTITY', @Total, SUM(HasQty), @Total - SUM(HasQty), CAST(SUM(HasQty) * 100 / @Total AS INT) FROM #Check
        UNION ALL
        SELECT 'BY_VALUE',   @Total, SUM(HasValue), @Total - SUM(HasValue), CAST(SUM(HasValue) * 100 / @Total AS INT) FROM #Check
        UNION ALL
        SELECT 'BY_DUTY',    @Total, SUM(HasDuty), @Total - SUM(HasDuty), CAST(SUM(HasDuty) * 100 / @Total AS INT) FROM #Check
        UNION ALL
        SELECT 'BY_TARIFF',  @Total, SUM(HasDuty), @Total - SUM(HasDuty), CAST(SUM(HasDuty) * 100 / @Total AS INT) FROM #Check
    ) AS Summary
    ORDER BY
        CASE Method
            WHEN 'BY_VOLUME'   THEN 1
            WHEN 'BY_WEIGHT'   THEN 2
            WHEN 'BY_QUANTITY' THEN 3
            WHEN 'BY_VALUE'    THEN 4
            WHEN 'BY_DUTY'     THEN 5
            WHEN 'BY_TARIFF'   THEN 6
        END;
END
GO
