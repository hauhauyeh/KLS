CREATE   PROCEDURE [dbo].[Report_PackingLabel]
    -- EXEC [Report_PackingLabel] '02/05/2026', 'E'
    @ShipDate   DATE,
    @ShipRoute  NVARCHAR(50)
AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    ;WITH cte AS
    (
        SELECT
            ROW_NUMBER() OVER (ORDER BY s.ShipRoute, p.PayeeName) AS Id,
            s.SalesNumber,
            s.ShipDate,
            s.ShipRoute,
            sd.ShipQty,
            sd.Unit,
            i.ItemName,
            p.PayeeName,
            RIGHT(s.SalesNumber, 3) AS Last3Digit,
            s.RouteOrder,
            sd.Notes,
            st.Zone AS Department,
            st.SortOrder,
            dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) AS LoadRoute,
            (
                SELECT TruckNumber
                FROM SalesRoute
                WHERE ShipDate = s.ShipDate
                  AND ShipRoute = s.ShipRoute
            ) AS TruckNumber
        FROM Sales AS s
        INNER JOIN SalesDetail AS sd ON s.SalesId = sd.SalesId
        INNER JOIN Item AS i ON i.ItemId = sd.ItemId
        INNER JOIN Payee AS p ON p.PayeeId = s.ShipId
        LEFT JOIN ItemStorage AS st ON st.StorageId = i.StorageId
        WHERE s.ShipDate = @ShipDate
          AND s.ShipRoute = CASE WHEN @ShipRoute IS NULL THEN s.ShipRoute ELSE @ShipRoute END
          AND (
                (st.Zone = 'Cooler' AND sd.ShipQty > 0 AND sd.Unit NOT IN ('cs', 'lbs'))
                OR (st.Zone = 'Store' AND sd.ShipQty > 0)
              )
    )
    SELECT * FROM cte
    ORDER BY
        CASE
            WHEN LoadRoute = ShipRoute THEN 0
            ELSE 1
        END,
        TRY_CAST(REPLACE(LoadRoute, ShipRoute, '') AS INT) DESC,
        SortOrder DESC,
        ItemName,
        PayeeName;
END
