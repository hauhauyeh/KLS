CREATE   PROCEDURE [dbo].[Shipment_ValidateAllocation]
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#Check') IS NOT NULL DROP TABLE #Check;

    SELECT
        pd.PurchaseDetailId,
        HasVolume = CASE WHEN ISNULL(pd.BaseFinalQty, 0) * ISNULL(pd.ItemVolume, 0) > 0 THEN 1 ELSE 0 END,
        HasWeight = CASE WHEN ISNULL(pd.BaseFinalQty, 0) * ISNULL(i.CaseWeight, 0) > 0 THEN 1 ELSE 0 END,
        HasQty    = CASE WHEN ISNULL(pd.BaseFinalQty, 0) > 0 THEN 1 ELSE 0 END,
        HasValue  = CASE WHEN ISNULL(pd.FinalQty, 0) * ISNULL(pd.FinalPrice, 0) > 0 THEN 1 ELSE 0 END,
        HasDuty   = CASE
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

