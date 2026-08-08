-- 2026-07-27 SalesDocNumber Slice 6: expose SalesDocNumber for invoice report model.
-- Baseline: KLS/SQL/2026-07-27/Report_Invoice_live_baseline.sql
CREATE   PROCEDURE [dbo].[Report_Invoice]
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ShipDate DATE, @ShipRoute VARCHAR(50), @RouteDrops INT;

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
        s.SalesDocNumber,
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
        ship.Address AS ShipAddress,
        ship.City AS ShipCity,
        ship.State AS ShipState,
        ship.ZipCode AS ShipZipCode,
        ship.Phone1 AS ShipPhone1,
        bill.PayeeName AS BillName,
        bill.Address AS BillAddress,
        bill.City AS BillCity,
        bill.State AS BillState,
        bill.ZipCode AS BillZipCode,
        bill.Phone1 AS BillPhone1,
        t.TermName,
        s.CustPONumber,
        ship.IsPastDue,
        ship.PayeePastDue,
        sr.Driver AS DriverName,
        rep.PayeeName AS SalesRepName,
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
