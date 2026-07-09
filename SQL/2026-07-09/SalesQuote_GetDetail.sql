USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- SalesQuote_GetDetail
-- 2026-07-09: surface LineType + AccountId, and show the
--   account name/code for freight/account lines via COALESCE
--   (LEFT JOIN Account). Item rows unchanged.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[SalesQuote_GetDetail]
    @SalesQuoteId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sqd.SalesQuoteDetailId,
        sqd.SalesQuoteId,
        sqd.LineId,
        sqd.LineType,
        sqd.ItemId,
        sqd.AccountId,
        sqd.ItemUnitId,
        sqd.Unit,
        sqd.OrdQty,
        sqd.UnitPrice,
        sqd.ExtTotal,
        sqd.DiscountPercent,
        sqd.Notes,
        sqd.IsTaxable,
        COALESCE(i.ItemName, a.AccountName) AS ItemName,
        COALESCE(i.ItemCode, a.AccountCode) AS ItemCode
    FROM dbo.SalesQuoteDetail AS sqd
    LEFT JOIN dbo.Item AS i
        ON i.ItemId = sqd.ItemId
    LEFT JOIN dbo.Account AS a
        ON a.AccountId = sqd.AccountId
    WHERE sqd.SalesQuoteId = @SalesQuoteId
    ORDER BY sqd.LineId;
END
GO
