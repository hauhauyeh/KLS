USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- Report_SalesQuote  (Sales Quote PDF detail)
-- 2026-07-09: include freight/account lines on the PDF.
--   Previously INNER JOIN Item + INNER JOIN ItemUnit silently
--   dropped account lines (NULL ItemId/ItemUnitId) and hardcoded
--   LineType 'I'. Now LEFT JOINs + real LineType + account
--   name/code (COALESCE with Account). Item rows are unchanged;
--   account rows have NULL item-only fields (weight -> 0).
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[Report_SalesQuote]
    @SalesQuoteId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CAST(ROW_NUMBER() OVER (ORDER BY sqd.LineId) AS INT) AS AutoId,
        COALESCE(i.ItemCode, a.AccountCode) AS ItemCode,
        COALESCE(i.ItemName, a.AccountName) AS ItemName,
        i.ItemName2,
        i.PackSize,
        ISNULL(sqd.LineType, 'I') AS LineType,
        sqd.Unit,
        sqd.UnitPrice,
        sqd.OrdQty AS ShipQty,
        sqd.OrdQty AS BillQty,
        sqd.ExtTotal,
        sqd.BaseOrdQty AS BaseShipQty,
        sqd.Notes,
        CAST(0 AS BIT) AS IsGroup,
        ISNULL(i.CaseWeight, 0) * ISNULL(sqd.BaseOrdQty, 0) AS ItemWeight,
        NULL AS AisleNum,
        NULL AS BayNum,
        iu.Barcode,
        NULL AS FIFOHistory,
        NULL AS FIFOHistoryOrder,
        NULL AS CatInvoiceDesc,
        sqd.IsTaxable,
        iu.P1 AS ListPrice
    FROM SalesQuoteDetail sqd
    LEFT JOIN Item i ON i.ItemId = sqd.ItemId
    LEFT JOIN ItemUnit iu ON iu.ItemUnitId = sqd.ItemUnitId
    LEFT JOIN Account a ON a.AccountId = sqd.AccountId
    WHERE sqd.SalesQuoteId = @SalesQuoteId
    ORDER BY sqd.LineId
END
GO
