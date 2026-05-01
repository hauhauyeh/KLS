SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Sales_ShipRouteDetail]
    @ShipDate DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.SalesId,
        s.ShipRoute,
        c.Region,
        s.SalesNumber,
        s.RouteOrder,
        s.IsLoadSeparate,
        -- Legacy retired field:
        -- s.LoadOrder,
        p.PayeeName,
        s.SalesTotal,
        CASE
            WHEN s.ShippingCarrierId IS NOT NULL
                THEN CONVERT(FLOAT, (SELECT GoogleLat FROM Payee WHERE PayeeId = s.ShippingCarrierId))
            ELSE CONVERT(FLOAT, p.GoogleLat)
        END AS GoogleLat,
        CASE
            WHEN s.ShippingCarrierId IS NOT NULL
                THEN CONVERT(FLOAT, (SELECT GoogleLong FROM Payee WHERE PayeeId = s.ShippingCarrierId))
            ELSE CONVERT(FLOAT, p.GoogleLong)
        END AS GoogleLong,
        (SELECT TruckNumber
         FROM SalesRoute AS t
         WHERE t.ShipDate = s.ShipDate
           AND t.ShipRoute = s.ShipRoute) AS TruckNumber
    FROM Sales s
    INNER JOIN Payee p ON s.ShipId = p.PayeeId
    INNER JOIN Customer c ON c.PayeeId = p.PayeeId
    WHERE ShipDate = @ShipDate
      AND s.ShipRoute NOT IN ('X', 'P', 'CM')
    ORDER BY ShipRoute, RouteOrder;
END
GO
