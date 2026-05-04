SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_Sensitive_1B_Test] --[Report_Sensitive_1B_Test] '02/02/2022'
    @ShipDate DATE
AS
BEGIN
    -- Keep the same grouped result while deriving the effective route from
    -- base sales columns instead of using CROSS APPLY with the scalar function.
    SET NOCOUNT ON;

    WITH SourceRows AS
    (
        SELECT
            s.ShipDate,
            i.ItemName,
            CASE
                WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
                WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND ISNULL(s.RouteOrder, 0) > 0
                    THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
                ELSE s.ShipRoute
            END AS EffectiveLoadRoute,
            sd.Unit,
            sd.ShipQty
        FROM Sales AS s
        INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
        INNER JOIN Item AS i ON sd.ItemId = i.ItemId
        WHERE s.ShipDate = @ShipDate
          AND i.ItemCode IN ('MUM', 'BS', 'MILK', 'MRE')
          AND s.ShipRoute NOT IN ('X', 'P')
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY ItemName, EffectiveLoadRoute) AS Id,
        ShipDate,
        ItemName,
        EffectiveLoadRoute AS ShipRoute,
        Unit,
        SUM(ShipQty) AS ShipQty
    FROM SourceRows
    GROUP BY
        ShipDate,
        ItemName,
        EffectiveLoadRoute,
        Unit
    ORDER BY
        ItemName,
        EffectiveLoadRoute;
END
GO
