USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- TempSalesQuote_GetList
-- 2026-07-09: split into item/account UNION (mirrors
--   TempSales_GetList). Account rows surface AccountName ->
--   ItemName, AccountCode -> ItemCode; item-only columns NULL.
--   Both branches carry LineType + AccountId.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[TempSalesQuote_GetList]
    @EmpId          INT,
    @PayeeId        INT,
    @SalesQuoteId   INT,
    @SortField      NVARCHAR(50) = NULL,
    @SortOrder      NVARCHAR(4) = NULL,
    @Id             INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Filtered AS
    (
        SELECT *
        FROM TempSalesQuote
        WHERE EmpId = @EmpId
          AND PayeeId = @PayeeId
          AND SalesQuoteId = @SalesQuoteId
          AND (@Id IS NULL OR TempSalesQuoteId = @Id)
    )
    SELECT
        t.TempSalesQuoteId,
        t.SalesQuoteId,
        t.PayeeId,
        t.LineId,
        t.LineType,
        t.ItemId,
        t.AccountId,
        t.ItemUnitId,
        t.Unit,
        t.OrdQty,
        t.UnitPrice,
        ROUND(ISNULL(t.OrdQty, 0) * ISNULL(t.UnitPrice, 0), 2) AS ExtTotal,
        t.DiscountPercent,
        t.FactorToBase,
        t.Notes,
        t.IsTaxable,
        t.ChangeStatus,
        t.IsStrike,
        i.ItemName,
        i.ItemCode,
        i.PackSize,
        i.CaseWeight,
        i.LCloseQty,
        iu_base.Unit AS BaseUnit,
        iu.P1 AS ListPrice
    FROM Filtered t
    INNER JOIN Item i ON i.ItemId = t.ItemId
    LEFT JOIN ItemUnit iu ON iu.ItemUnitId = t.ItemUnitId
    LEFT JOIN ItemUnit iu_base ON iu_base.ItemId = t.ItemId AND iu_base.IsBaseUnit = 1
    WHERE t.ItemId IS NOT NULL

    UNION ALL

    SELECT
        t.TempSalesQuoteId,
        t.SalesQuoteId,
        t.PayeeId,
        t.LineId,
        t.LineType,
        t.ItemId,
        t.AccountId,
        t.ItemUnitId,
        t.Unit,
        t.OrdQty,
        t.UnitPrice,
        ROUND(ISNULL(t.OrdQty, 0) * ISNULL(t.UnitPrice, 0), 2) AS ExtTotal,
        t.DiscountPercent,
        t.FactorToBase,
        t.Notes,
        t.IsTaxable,
        t.ChangeStatus,
        t.IsStrike,
        a.AccountName AS ItemName,
        a.AccountCode AS ItemCode,
        NULL AS PackSize,
        NULL AS CaseWeight,
        NULL AS LCloseQty,
        NULL AS BaseUnit,
        NULL AS ListPrice
    FROM Filtered t
    INNER JOIN Account a ON a.AccountId = t.AccountId
    WHERE t.AccountId IS NOT NULL
    ORDER BY TempSalesQuoteId;
END
GO
