SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================================================================
-- Tariff Phase 4 - Purchase tariff rate precheck
-- Date : 2026-07-23
-- Plan : plan-tariff-phase-4-precheck-refresh-backend.md
-- Purpose: compare bill line duty/tariff snapshots with current ItemTariff setup.
-- =============================================================================================
CREATE OR ALTER PROCEDURE [dbo].[Purchase_TariffRatePrecheck] -- EXEC dbo.Purchase_TariffRatePrecheck @PurchaseId = 0
    @PurchaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pd.PurchaseDetailId,
        pd.PurchaseId,
        pd.LineId,
        pd.ItemId,
        i.ItemCode,
        i.ItemName,
        vc.CountryCode,
        it.HSNCode,
        LineDutyRate = pd.CustomDutyRate,
        LineTariffRate = pd.TariffPercent,
        CurrentDutyRate = it.DutyRate,
        CurrentTariffRate = it.TariffRate,
        [Status] = CASE
            WHEN vc.CountryCode IS NULL THEN 'NO_COUNTRY'
            WHEN it.ItemTariffId IS NULL THEN 'MISSING_SETUP'
            WHEN (pd.CustomDutyRate IS NULL AND it.DutyRate IS NOT NULL)
              OR (pd.CustomDutyRate IS NOT NULL AND it.DutyRate IS NULL)
              OR (pd.CustomDutyRate IS NOT NULL AND it.DutyRate IS NOT NULL AND pd.CustomDutyRate <> it.DutyRate)
              OR (pd.TariffPercent IS NULL AND it.TariffRate IS NOT NULL)
              OR (pd.TariffPercent IS NOT NULL AND it.TariffRate IS NULL)
              OR (pd.TariffPercent IS NOT NULL AND it.TariffRate IS NOT NULL AND pd.TariffPercent <> it.TariffRate) THEN 'DIFFERENT'
            ELSE 'MATCH'
        END
    FROM dbo.PurchaseDetail pd
    INNER JOIN dbo.Item i ON i.ItemId = pd.ItemId
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
    ORDER BY pd.LineId, pd.PurchaseDetailId;
END
GO
