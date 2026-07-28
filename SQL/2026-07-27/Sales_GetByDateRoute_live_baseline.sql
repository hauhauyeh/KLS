CREATE PROCEDURE [dbo].[Sales_GetByDateRoute]

	@ShipDate DATE,
	@ShipRoute NVARCHAR(20)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT 
	    s.SalesId,
	    s.ShipRoute,
	    c.Region,
	    s.SalesNumber,
	    s.RouteOrder,
	    s.IsLoadSeparate,
	    --s.LoadOrder,
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
        sr.TruckNumber,
        ISNULL(w.WeightTotal, 0) AS WeightTotal
	FROM Sales s INNER JOIN Payee p ON p.PayeeId=s.ShipId 
	INNER JOIN Customer c ON c.PayeeId = p.PayeeId
	LEFT JOIN SalesRoute sr
        ON sr.ShipDate = s.ShipDate
       AND sr.ShipRoute = s.ShipRoute
    OUTER APPLY
    (
        SELECT
            ROUND(SUM(sd.BaseShipQty * i.CaseWeight), 2) AS WeightTotal
        FROM SalesDetail sd
        INNER JOIN Item i
            ON i.ItemId = sd.ItemId
        WHERE sd.SalesId = s.SalesId
    ) w
	WHERE s.ShipDate=@ShipDate AND s.ShipRoute=@ShipRoute 
	ORDER BY s.RouteOrder,p.PayeeName

END


