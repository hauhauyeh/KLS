SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP PROCEDURE IF EXISTS [dbo].[ItemUnit_GetViewList]
GO
CREATE PROCEDURE [dbo].[ItemUnit_GetViewList] -- EXEC ItemUnit_GetViewList @ItemIds='421,770'
    @ItemIds NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @ItemIds IS NULL OR @ItemIds = ''
    BEGIN
        SELECT TOP 0
            0 AS ItemId,
            '' AS ItemCode,
            '' AS ItemName,
            '' AS ImagePath,
            0 AS ItemUnitId,
            '' AS Unit,
            CAST(0 AS BIT) AS IsBaseUnit,
            CAST(0 AS BIT) AS IsDefaultSalesUnit,
            CAST(0 AS DECIMAL(18,6)) AS FactorToBase,
            -- 2026-07-02: added MultipleToBase (numerator of the unit ratio; denominator = FactorToBase).
            -- item-tab-unit reads it to render the read-only ×N / ÷N ratio badge (A.5). Existing rows are
            -- MultipleToBase = 1 (=> ÷FactorToBase); combine-up units are MultipleToBase = N, FactorToBase = 1.
            CAST(0 AS INT) AS MultipleToBase,
            CAST(0 AS DECIMAL(18,2)) AS RecentCost,
            CAST(0 AS DECIMAL(18,2)) AS P1,
            '' AS Barcode,
            CAST(0 AS BIT) AS Inactive,
            CAST(0 AS DECIMAL(18,4)) AS PricePercentToBase;

        RETURN;
    END;

    DECLARE @DefaultPercent DECIMAL(18,4);

    SELECT
        @DefaultPercent = CAST(SettingValue AS DECIMAL(18,4))
    FROM SystemSetting
    WHERE SettingKey = 'ITEM_DEFAULT_RETAILPROFIT';

    SELECT
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        CASE
            WHEN img.ImageId IS NOT NULL AND img.Has300 = 1
                THEN '/Images/items/' + CAST(i.ItemId AS VARCHAR(10)) + '/' + CAST(img.ImageIndex AS VARCHAR(10)) + '-300.png'
            ELSE NULL
        END AS ImagePath,
        iu.ItemUnitId,
        iu.Unit,
        iu.IsBaseUnit,
        iu.IsDefaultSalesUnit,
        iu.FactorToBase,
        iu.MultipleToBase,   -- 2026-07-02: for the ×N / ÷N ratio badge in item-tab-unit
        iu.RecentCost,
        iu.P1,
        iu.Barcode,
        iu.Inactive,
        ISNULL(NULLIF(iu.PricePercentToBase, 0), @DefaultPercent) AS PricePercentToBase
    FROM STRING_SPLIT(@ItemIds, ',', 1) ss
    INNER JOIN Item i
        ON i.ItemId = CAST(ss.value AS INT)
    INNER JOIN ItemUnit iu
        ON iu.ItemId = i.ItemId
    OUTER APPLY
    (
        SELECT TOP 1
            ImageId,
            ImageIndex,
            Has300
        FROM ItemImage
        WHERE ItemId = i.ItemId
          AND IsPrimary = 1
    ) img
    ORDER BY
        ss.ordinal,
        CASE
            WHEN iu.IsBaseUnit = 1 THEN 0
            ELSE 1
        END,
        iu.ItemUnitId;
END
GO
