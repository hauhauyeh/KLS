SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ASB_ELIGIBLE_20260813_ADVANCE: bills eligible to be added to a shipment
-- (picker source for the Add-Bills modal).
-- Eligible = bill stage (StageId = 6), not a shipment bill (IsShipment = 0),
-- not already assigned to ANY shipment, not locked, and not normally paid.
-- Advance Bill Payment applied to the bill is allowed; normal vendor payment
-- applied to the bill is still treated as financially final and excluded.
-- @ShipmentId is accepted for endpoint/context symmetry (route is
-- /Shipments/{shipmentId}/EligibleBills); eligibility itself is
-- global-unassigned, so it is not used for filtering today.
-- Parameterized search (no dynamic SQL); capped at 100 rows - the modal is
-- search-driven.
CREATE   PROCEDURE [dbo].[Shipment_EligibleBills]
    @ShipmentId INT,
    @Search     NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @S NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@Search)), '');

    SELECT TOP (100)
        v.PayeeName,
        p.PurchaseId,
        p.PurchaseNumber,
        p.StageId,
        p.PayeeId,
        p.ArrivalDate,
        p.VendorDocNumber,
        p.ContainerNumber,
        p.PurchaseTotal,
        p.IsLocked,
        p.IsDropShip   -- 2026-07-13 DROPSHIP-EXCLUDE (Slice B): picker badge
    FROM dbo.Purchase AS p
    INNER JOIN dbo.Payee AS v ON v.PayeeId = p.PayeeId
    WHERE p.StageId = 6
      AND ISNULL(p.IsShipment, 0) = 0
      AND NOT EXISTS (SELECT 1 FROM dbo.ShipmentPurchase sp WHERE sp.PurchaseId = p.PurchaseId)
      AND ISNULL(p.IsLocked, 0) = 0
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.VendorPaymentDetail vpd
          INNER JOIN dbo.VendorPayment vp ON vp.VendorPaymentId = vpd.VendorPaymentId
          WHERE vpd.PurchaseId = p.PurchaseId
            AND ISNULL(vpd.PaymentApplied, 0) <> 0
            AND ISNULL(vp.PaymentType, '') <> 'Advance Bill Payment'
      )
      -- 2026-07-13 REQUIRE-ITEM-LINES: only bills with >=1 real item line are shipment-eligible
      -- (landed-cost needs inventory lines; account-only/service bills have no shipment role).
      AND EXISTS (
          SELECT 1 FROM dbo.PurchaseDetail pd
          WHERE pd.PurchaseId = p.PurchaseId AND pd.LineType = 'I' AND pd.ItemId IS NOT NULL
      )
      AND (
            @S IS NULL
            OR (TRY_CAST(@S AS INT) IS NOT NULL AND p.PurchaseNumber = TRY_CAST(@S AS INT))
            OR p.VendorDocNumber LIKE '%' + @S + '%'
            OR p.ContainerNumber LIKE '%' + @S + '%'
            OR v.PayeeName        LIKE '%' + @S + '%'
      )
    ORDER BY p.PurchaseNumber DESC;
END
