
CREATE PROCEDURE [dbo].[Report_Invoice]
	@SalesId INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    DECLARE @ShipDate date, @ShipRoute varchar(50), @RouteDrops int;

    SELECT
        @ShipDate = s.ShipDate,
        @ShipRoute = s.ShipRoute
    FROM dbo.Sales s
    WHERE s.SalesId = @SalesId;

    SELECT
        @RouteDrops = COUNT(SalesId)
    FROM dbo.Sales s
    WHERE s.ShipDate = @ShipDate
      AND s.ShipRoute = @ShipRoute;

    SELECT
    s.SalesId,
    s.SalesNumber,
    s.DocType,
    s.ParentSalesNumber,
    s.ShipId,
    s.ShipDate,
    s.ShipRoute,
    s.RouteOrder,
    s.SubTotal,
    s.TaxTotal,
    s.SalesTotal,
    s.Instruction,
    ship.PayeeName AS ShipName,
    ship.Address   AS ShipAddress,
    ship.City      AS ShipCity,
    ship.State     AS ShipState,
    ship.ZipCode   AS ShipZipCode,
    ship.Phone1    AS ShipPhone1,
    bill.PayeeName AS BillName,
    bill.Address   AS BillAddress,
    bill.City      AS BillCity,
    bill.State     AS BillState,
    bill.ZipCode   AS BillZipCode,
    bill.Phone1    AS BillPhone1,
    t.TermName,
    s.CustPONumber,
    ship.IsPastDue,
    ship.PayeePastDue,
    sr.Driver      AS DriverName,
    rep.PayeeName  AS SalesRepName,
    sr.TruckNumber AS TruckNumber,
    s.IsLoadSeparate,
    s.ShippingCarrierId,
    @RouteDrops AS RouteDrops
    FROM dbo.Sales AS s
    INNER JOIN dbo.Payee AS ship ON ship.PayeeId = s.ShipId
    INNER JOIN dbo.Payee AS bill ON bill.PayeeId = s.BillId
    INNER JOIN dbo.Term AS t ON t.TermId = s.TermId
    LEFT JOIN dbo.SalesRoute AS sr ON sr.ShipDate = s.ShipDate AND sr.ShipRoute = s.ShipRoute
    LEFT JOIN dbo.Payee AS rep ON rep.PayeeId = s.SalesRepId
    WHERE s.SalesId = @SalesId;
END



