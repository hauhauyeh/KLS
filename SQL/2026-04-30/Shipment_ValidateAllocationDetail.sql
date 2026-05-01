-- ============================================================
-- Shipment_ValidateAllocationDetail
-- Returns missing items for a specific active allocation method.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[Shipment_ValidateAllocationDetail]
    @PurchaseId INT,
    @Method VARCHAR(20)
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
            WHEN 'BY_DUTY'     THEN 'DutyWeight (Qty * Price * Rate)'
            WHEN 'BY_TARIFF'   THEN 'DutyWeight (Qty * Price * Rate)'
            ELSE ''
        END
    FROM dbo.PurchaseDetail pd
    JOIN dbo.Item i ON pd.ItemId = i.ItemId
    WHERE pd.PurchaseId = @PurchaseId
      AND pd.ItemId IS NOT NULL
      AND i.ItemType = 'Inventory'
      AND CASE @Method
            WHEN 'BY_VOLUME'   THEN CASE WHEN ISNULL(pd.BaseFinalQty, 0) * ISNULL(pd.ItemVolume, 0) > 0 THEN 1 ELSE 0 END
            WHEN 'BY_WEIGHT'   THEN CASE WHEN ISNULL(pd.BaseFinalQty, 0) * ISNULL(i.CaseWeight, 0) > 0 THEN 1 ELSE 0 END
            WHEN 'BY_QUANTITY' THEN CASE WHEN ISNULL(pd.BaseFinalQty, 0) > 0 THEN 1 ELSE 0 END
            WHEN 'BY_VALUE'    THEN CASE WHEN ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0) > 0 THEN 1 ELSE 0 END
            WHEN 'BY_DUTY'     THEN CASE WHEN (ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0)) * (ISNULL(pd.CustomDutyRate, 0) + ISNULL(pd.TariffPercent, 0)) > 0 THEN 1 ELSE 0 END
            WHEN 'BY_TARIFF'   THEN CASE WHEN (ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0)) * (ISNULL(pd.CustomDutyRate, 0) + ISNULL(pd.TariffPercent, 0)) > 0 THEN 1 ELSE 0 END
          END = 0
    ORDER BY i.ItemCode;
END
