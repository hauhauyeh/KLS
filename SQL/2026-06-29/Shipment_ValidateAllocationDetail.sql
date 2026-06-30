SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- 2026-06-29 (Plan 1 — shipment-allocation-completeness-guard):
--   Lists the items that are MISSING data for a given allocation @Method. Two changes to match the
--   allocation guard (same as Shipment_ValidateAllocation):
--   (1) ATTRIBUTE-PRESENCE filter (ItemVolume>0, CaseWeight>0, CustomDutyRate+TariffPercent>0) so a
--       free line isn't falsely listed as missing, and MissingField labels name the actual attribute.
--   (2) Optional @ShipmentId for shipment-scope (all bills in the shipment) vs bill-scope preview.
-- =============================================================================================

DROP PROCEDURE IF EXISTS [dbo].[Shipment_ValidateAllocationDetail]
GO

CREATE PROCEDURE [dbo].[Shipment_ValidateAllocationDetail] -- EXEC Shipment_ValidateAllocationDetail @PurchaseId=12164,@Method='BY_VOLUME'
-- EXEC Shipment_ValidateAllocationDetail @ShipmentId=7,@Method='BY_VOLUME'
    -- 2026-06-29: @PurchaseId made optional, @ShipmentId added (one drives the scope).
    -- removed: @PurchaseId INT
    @PurchaseId INT = NULL,
    @Method     VARCHAR(20),
    @ShipmentId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        MissingField = CASE @Method
            WHEN 'BY_VOLUME'   THEN 'ItemVolume'
            WHEN 'BY_WEIGHT'   THEN 'CaseWeight'
            WHEN 'BY_QUANTITY' THEN 'BaseFinalQty'
            WHEN 'BY_VALUE'    THEN 'FinalQty * FinalPrice'
            -- 2026-06-29: duty/tariff label now names the missing attribute (was 'DutyWeight (Qty * Price * Rate)')
            -- WHEN 'BY_DUTY'     THEN 'DutyWeight (Qty * Price * Rate)'
            -- WHEN 'BY_TARIFF'   THEN 'DutyWeight (Qty * Price * Rate)'
            WHEN 'BY_DUTY'     THEN 'CustomDutyRate + TariffPercent'
            WHEN 'BY_TARIFF'   THEN 'CustomDutyRate + TariffPercent'
            ELSE ''
        END
    FROM dbo.PurchaseDetail pd
    JOIN dbo.Item i ON pd.ItemId = i.ItemId
    WHERE pd.ItemId IS NOT NULL
      AND i.ItemType = 'Inventory'
      -- 2026-06-29: scope selector. @ShipmentId wins when supplied (all bills in the shipment),
      -- otherwise bill scope by @PurchaseId.
      -- replaced: AND pd.PurchaseId = @PurchaseId
      AND (
            (@ShipmentId IS NOT NULL
                 AND pd.PurchaseId IN (SELECT sp.PurchaseId FROM dbo.ShipmentPurchase sp WHERE sp.ShipmentId = @ShipmentId))
         OR (@ShipmentId IS NULL
                 AND pd.PurchaseId = @PurchaseId)
          )
      -- keep only lines that are MISSING data for @Method (the HAS check = 0)
      AND CASE @Method
            -- 2026-06-29: attribute-presence (was qty/value-scaled). Old versions kept for reference:
            -- WHEN 'BY_VOLUME' THEN CASE WHEN ISNULL(pd.BaseFinalQty,0)*ISNULL(pd.ItemVolume,0) > 0 THEN 1 ELSE 0 END
            -- WHEN 'BY_WEIGHT' THEN CASE WHEN ISNULL(pd.BaseFinalQty,0)*ISNULL(i.CaseWeight,0) > 0 THEN 1 ELSE 0 END
            -- WHEN 'BY_DUTY'   THEN CASE WHEN (ISNULL(pd.FinalQty,0)*ISNULL(pd.FinalPrice,0))*(ISNULL(pd.CustomDutyRate,0)+ISNULL(pd.TariffPercent,0)) > 0 THEN 1 ELSE 0 END
            -- WHEN 'BY_TARIFF' THEN CASE WHEN (ISNULL(pd.FinalQty,0)*ISNULL(pd.FinalPrice,0))*(ISNULL(pd.CustomDutyRate,0)+ISNULL(pd.TariffPercent,0)) > 0 THEN 1 ELSE 0 END
            WHEN 'BY_VOLUME'   THEN CASE WHEN ISNULL(pd.ItemVolume, 0) > 0 THEN 1 ELSE 0 END
            WHEN 'BY_WEIGHT'   THEN CASE WHEN ISNULL(i.CaseWeight, 0) > 0 THEN 1 ELSE 0 END
            WHEN 'BY_QUANTITY' THEN CASE WHEN ISNULL(pd.BaseFinalQty, 0) > 0 THEN 1 ELSE 0 END
            WHEN 'BY_VALUE'    THEN CASE WHEN ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0) > 0 THEN 1 ELSE 0 END
            WHEN 'BY_DUTY'     THEN CASE WHEN (ISNULL(pd.CustomDutyRate, 0) + ISNULL(pd.TariffPercent, 0)) > 0 THEN 1 ELSE 0 END
            WHEN 'BY_TARIFF'   THEN CASE WHEN (ISNULL(pd.CustomDutyRate, 0) + ISNULL(pd.TariffPercent, 0)) > 0 THEN 1 ELSE 0 END
          END = 0
    ORDER BY i.ItemCode;
END
GO
