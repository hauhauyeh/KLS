SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-08-07 DropShip refs Slice 4: expose linked purchase refs and chain sequence label.
-- 2026-07-27 SalesDocNumber Slice 6: expose SalesDocNumber for invoice report model.
-- Baseline: KLS/SQL/2026-07-27/Report_Invoice_live_baseline.sql
CREATE OR ALTER PROCEDURE [dbo].[Report_Invoice]
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
        s.IsDropShip,
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
        CASE WHEN s.IsDropShip = 1 THEN dsp.FactorPO ELSE NULL END AS DropShipPurchaseFactorPO,
        CASE WHEN s.IsDropShip = 1 THEN dsp.VendorDocNumber ELSE NULL END AS DropShipPurchaseVendorDocNumber,
        CASE WHEN s.IsDropShip = 1 THEN dsp.ContainerNumber ELSE NULL END AS DropShipPurchaseContainerNumber,
        -- Calculate root/child drop-ship sequence on demand; the root order is always first.
        CASE
            WHEN s.IsDropShip = 1 THEN
            (
                SELECT CONCAT(chainSeq.ChainOrdinal,
                    CASE
                        WHEN chainSeq.ChainOrdinal % 100 BETWEEN 11 AND 13 THEN 'th'
                        WHEN chainSeq.ChainOrdinal % 10 = 1 THEN 'st'
                        WHEN chainSeq.ChainOrdinal % 10 = 2 THEN 'nd'
                        WHEN chainSeq.ChainOrdinal % 10 = 3 THEN 'rd'
                        ELSE 'th'
                    END)
                FROM
                (
                    SELECT
                        chainRow.SalesNumber,
                        ROW_NUMBER() OVER
                        (
                            ORDER BY
                                CASE WHEN chainRow.SalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber) THEN 0 ELSE 1 END,
                                chainRow.CreatedAt,
                                chainRow.SalesNumber
                        ) AS ChainOrdinal
                    FROM dbo.Sales AS chainRow
                    WHERE chainRow.SalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber)
                       OR chainRow.ParentSalesNumber = COALESCE(s.ParentSalesNumber, s.SalesNumber)
                ) AS chainSeq
                WHERE chainSeq.SalesNumber = s.SalesNumber
            )
            ELSE NULL
        END AS DropShipChainLabel,
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
    LEFT JOIN dbo.Purchase AS dsp ON dsp.PurchaseId = s.DropShipPurchaseId
    WHERE s.SalesId = @SalesId;
END
