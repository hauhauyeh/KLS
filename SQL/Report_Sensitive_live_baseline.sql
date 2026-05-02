CREATE   PROCEDURE [dbo].[Report_Sensitive] --[Report_Sensitive] '02/02/2022'
    @ShipDate DATE
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    SELECT
        ROW_NUMBER() OVER (ORDER BY i.ItemName, EffectiveLoadRoute) AS Id,
        s.ShipDate,
        i.ItemName,
        EffectiveLoadRoute AS ShipRoute,
        sd.Unit,
        SUM(sd.ShipQty) AS ShipQty
    FROM Sales AS s
    INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
    INNER JOIN Item AS i ON sd.ItemId = i.ItemId
    CROSS APPLY
    (
        SELECT dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) AS EffectiveLoadRoute
    ) AS lr
    WHERE s.ShipDate = @ShipDate
      AND i.ItemCode IN ('MUM', 'BS', 'MILK', 'MRE')
      AND s.ShipRoute NOT IN ('X', 'P')
    GROUP BY
        s.ShipDate,
        i.ItemName,
        lr.EffectiveLoadRoute,
        sd.Unit
    ORDER BY
        i.ItemName,
        EffectiveLoadRoute;
END
