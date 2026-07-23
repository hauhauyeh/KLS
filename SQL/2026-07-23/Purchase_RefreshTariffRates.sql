SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================================================================
-- Tariff Phase 4 - Refresh purchase line tariff rates
-- Date : 2026-07-23
-- Plan : plan-tariff-phase-4-precheck-refresh-backend.md
-- Purpose: update bill line duty/tariff snapshots from current ItemTariff setup only on request.
-- =============================================================================================
CREATE OR ALTER PROCEDURE [dbo].[Purchase_RefreshTariffRates] -- EXEC dbo.Purchase_RefreshTariffRates @PurchaseId = 0
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Purchase WHERE PurchaseId = @PurchaseId)
        THROW 50000, 'Purchase was not found.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Purchase WHERE PurchaseId = @PurchaseId AND ISNULL(StageId, 0) <> 6)
        THROW 50000, 'Tariff rates can only be refreshed for billed purchases.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Purchase WHERE PurchaseId = @PurchaseId AND IsLocked = 1)
        THROW 50000, 'Tariff rates cannot be refreshed because this bill is locked.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Purchase WHERE PurchaseId = @PurchaseId AND ISNULL(PaymentApplied, 0) > 0)
        THROW 50000, 'Tariff rates cannot be refreshed because this bill has payment applied.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ShipmentPurchase sp
        INNER JOIN dbo.Purchase shipmentBill
          ON shipmentBill.IsShipment = 1
         AND shipmentBill.SourceShipmentId = sp.ShipmentId
        WHERE sp.PurchaseId = @PurchaseId
          AND (shipmentBill.IsLocked = 1 OR ISNULL(shipmentBill.PaymentApplied, 0) > 0)
    )
        THROW 50000, 'Tariff rates cannot be refreshed because the generated shipment vendor bill is locked or paid.', 1;

    DECLARE @Updated TABLE (PurchaseDetailId INT NOT NULL);
    DECLARE @SkippedMissingSetupCount INT;

    ;WITH Eligible AS
    (
        SELECT
            pd.PurchaseDetailId,
            CurrentDutyRate = it.DutyRate,
            CurrentTariffRate = it.TariffRate
        FROM dbo.PurchaseDetail pd
        INNER JOIN dbo.Purchase p ON p.PurchaseId = pd.PurchaseId
        LEFT JOIN dbo.Payee py ON py.PayeeId = p.PayeeId
        OUTER APPLY
        (
            SELECT TOP (1)
                CountryCode = UPPER(LTRIM(RTRIM(c.ISOAlpha2)))
            FROM dbo.Country c
            WHERE c.IsActive = 1
              AND (
                    UPPER(LTRIM(RTRIM(c.ISOAlpha2))) = UPPER(LTRIM(RTRIM(py.CountryCode)))
                 OR UPPER(LTRIM(RTRIM(c.ISOAlpha3))) = UPPER(LTRIM(RTRIM(py.CountryCode)))
                 OR UPPER(LTRIM(RTRIM(c.CountryCode))) = UPPER(LTRIM(RTRIM(py.CountryCode)))
                 OR UPPER(LTRIM(RTRIM(c.CountryName))) = UPPER(LTRIM(RTRIM(py.Country)))
                 OR UPPER(LTRIM(RTRIM(c.ISOAlpha2))) = UPPER(LTRIM(RTRIM(py.Country)))
                 OR UPPER(LTRIM(RTRIM(c.ISOAlpha3))) = UPPER(LTRIM(RTRIM(py.Country)))
                 OR UPPER(LTRIM(RTRIM(c.CountryCode))) = UPPER(LTRIM(RTRIM(py.Country)))
              )
        ) vc
        INNER JOIN dbo.ItemTariff it
          ON it.ItemId = pd.ItemId
         AND it.CountryCode = vc.CountryCode
        WHERE pd.PurchaseId = @PurchaseId
          AND pd.LineType = 'I'
          AND pd.ItemId IS NOT NULL
    )
    UPDATE pd
       SET CustomDutyRate = e.CurrentDutyRate,
           TariffPercent = e.CurrentTariffRate
    OUTPUT inserted.PurchaseDetailId INTO @Updated (PurchaseDetailId)
    FROM dbo.PurchaseDetail pd
    INNER JOIN Eligible e ON e.PurchaseDetailId = pd.PurchaseDetailId
    WHERE (pd.CustomDutyRate IS NULL AND e.CurrentDutyRate IS NOT NULL)
       OR (pd.CustomDutyRate IS NOT NULL AND e.CurrentDutyRate IS NULL)
       OR (pd.CustomDutyRate IS NOT NULL AND e.CurrentDutyRate IS NOT NULL AND pd.CustomDutyRate <> e.CurrentDutyRate)
       OR (pd.TariffPercent IS NULL AND e.CurrentTariffRate IS NOT NULL)
       OR (pd.TariffPercent IS NOT NULL AND e.CurrentTariffRate IS NULL)
       OR (pd.TariffPercent IS NOT NULL AND e.CurrentTariffRate IS NOT NULL AND pd.TariffPercent <> e.CurrentTariffRate);

    ;WITH InventoryLines AS
    (
        SELECT
            pd.PurchaseDetailId,
            vc.CountryCode,
            it.ItemTariffId
        FROM dbo.PurchaseDetail pd
        INNER JOIN dbo.Purchase p ON p.PurchaseId = pd.PurchaseId
        LEFT JOIN dbo.Payee py ON py.PayeeId = p.PayeeId
        OUTER APPLY
        (
            SELECT TOP (1)
                CountryCode = UPPER(LTRIM(RTRIM(c.ISOAlpha2)))
            FROM dbo.Country c
            WHERE c.IsActive = 1
              AND (
                    UPPER(LTRIM(RTRIM(c.ISOAlpha2))) = UPPER(LTRIM(RTRIM(py.CountryCode)))
                 OR UPPER(LTRIM(RTRIM(c.ISOAlpha3))) = UPPER(LTRIM(RTRIM(py.CountryCode)))
                 OR UPPER(LTRIM(RTRIM(c.CountryCode))) = UPPER(LTRIM(RTRIM(py.CountryCode)))
                 OR UPPER(LTRIM(RTRIM(c.CountryName))) = UPPER(LTRIM(RTRIM(py.Country)))
                 OR UPPER(LTRIM(RTRIM(c.ISOAlpha2))) = UPPER(LTRIM(RTRIM(py.Country)))
                 OR UPPER(LTRIM(RTRIM(c.ISOAlpha3))) = UPPER(LTRIM(RTRIM(py.Country)))
                 OR UPPER(LTRIM(RTRIM(c.CountryCode))) = UPPER(LTRIM(RTRIM(py.Country)))
              )
        ) vc
        LEFT JOIN dbo.ItemTariff it
          ON it.ItemId = pd.ItemId
         AND it.CountryCode = vc.CountryCode
        WHERE pd.PurchaseId = @PurchaseId
          AND pd.LineType = 'I'
          AND pd.ItemId IS NOT NULL
    )
    SELECT @SkippedMissingSetupCount = COUNT(*)
    FROM InventoryLines
    WHERE CountryCode IS NULL OR ItemTariffId IS NULL;

    SELECT
        UpdatedCount = COUNT(1),
        SkippedMissingSetupCount = @SkippedMissingSetupCount
    FROM @Updated;
END
GO
