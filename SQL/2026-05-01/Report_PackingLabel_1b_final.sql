SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_PackingLabel]
    -- EXEC [Report_PackingLabel] '02/05/2026', 'E'
    @ShipDate   DATE,
    @ShipRoute  NVARCHAR(50)
AS
BEGIN
    -- Keep the same report rowset as the live baseline while moving
    -- LoadRoute derivation and sort behavior onto base columns.
    SET NOCOUNT ON;

    ;WITH SourceRows AS
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
            CASE
                WHEN NULLIF(LTRIM(RTRIM(s.ShipRoute)), '') IS NULL THEN NULL
                WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND ISNULL(s.RouteOrder, 0) > 0
                    THEN s.ShipRoute + CONVERT(VARCHAR(12), s.RouteOrder)
                ELSE s.ShipRoute
            END AS LoadRoute,
            CASE
                WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND ISNULL(s.RouteOrder, 0) > 0 THEN 1
                ELSE 0
            END AS LoadRouteSortGroup,
            CASE
                WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND ISNULL(s.RouteOrder, 0) > 0 THEN s.RouteOrder
                ELSE NULL
            END AS LoadRouteSortOrder,
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
    SELECT
        Id,
        SalesNumber,
        ShipDate,
        ShipRoute,
        ShipQty,
        Unit,
        ItemName,
        PayeeName,
        Last3Digit,
        RouteOrder,
        Notes,
        Department,
        SortOrder,
        LoadRoute,
        TruckNumber
    FROM SourceRows
    ORDER BY
        LoadRouteSortGroup,
        ISNULL(LoadRouteSortOrder, 0) DESC,
        SortOrder DESC,
        ItemName,
        PayeeName;
END
GO
