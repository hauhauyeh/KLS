SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- FIX_ICREDIT_AMOUNT_SIGN 2026-07-17 (reader): Revenue now sums td.CrDeAmount over @ISALE+@ICREDIT
-- instead of td.Amount. For revenue detail rows CrDeAmount = the signed line value under BOTH the
-- old (buggy) and new posting conventions (@ISALE credit-normal: +value; @ICREDIT debit-normal:
-- -magnitude = the negative line value), so this report returns IDENTICAL results before and after
-- the Amount-sign data fix (TxDetail_FixAmountSign_292_310.sql). Without this change, the data fix
-- would flip @ICREDIT Amount to +magnitude and credit memos would ADD to Revenue instead of
-- netting it down. Cost (@COGS) stays on td.Amount -- COGS posting convention is unchanged.
-- See baseline: KLS/SQL/2026-07-17/Report_SalesByInvoice_live_baseline.sql
CREATE OR ALTER PROCEDURE [dbo].[Report_SalesByInvoice] -- EXEC Report_SalesByInvoice @StartDate='2026-06-01',@EndDate='2026-06-26',@SalesRep=NULL
-- EXEC Report_SalesByInvoice @StartDate='2026-06-01',@EndDate='2026-06-26',@SalesRep=123
    @StartDate DATE,
    @EndDate   DATE,
    @SalesRep  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ISALE   INT = (SELECT AccountId FROM Account WHERE AccountCode = '@ISALE');
    DECLARE @ICREDIT INT = (SELECT AccountId FROM Account WHERE AccountCode = '@ICREDIT');
    DECLARE @COGS    INT = (SELECT AccountId FROM Account WHERE AccountCode = '@COGS');

    ;WITH InvScope AS
    (
        SELECT s.SalesId, s.SalesNumber, s.SalesDocNumber, s.ShipDate, s.ShipRoute, s.DocType,
               s.ParentSalesNumber, s.ShipId, s.SalesRepId, s.SalesTotal
        FROM Sales s
        WHERE s.ShipDate BETWEEN @StartDate AND @EndDate
          AND s.SalesRepId = CASE WHEN @SalesRep IS NOT NULL THEN @SalesRep ELSE s.SalesRepId END
    ),
    InvJournal AS
    (
        SELECT t.SourceDocNumber AS SalesNumber,
               ISNULL(SUM(CASE WHEN td.AccountId IN (@ISALE, @ICREDIT) THEN td.CrDeAmount END), 0) AS Revenue,
               ISNULL(SUM(CASE WHEN td.AccountId = @COGS THEN td.Amount END), 0) AS Cost
        FROM TransactionJournal t
        JOIN TransactionJournalDetail td ON td.TxId = t.TxId
        WHERE t.SourceDocType IN ('Sales', 'Sales Credit Memo')
          AND t.SourceDocNumber IN (SELECT SalesNumber FROM InvScope)
        GROUP BY t.SourceDocNumber
    )
    SELECT
        s.SalesId,
        s.SalesNumber,
        s.SalesDocNumber,
        s.ShipDate,
        s.ShipRoute,
        s.DocType,
        s.ParentSalesNumber,
        s.ShipId,
        p.PayeeName AS Customer,
        s.SalesRepId,
        CAST(s.SalesTotal AS DECIMAL(18,2)) AS InvoiceTotal,
        CAST(ISNULL(j.Revenue, 0) AS DECIMAL(18,2)) AS Amount,
        CAST(ISNULL(j.Cost, 0)    AS DECIMAL(18,2)) AS Cost,
        CAST(ISNULL(j.Revenue, 0) - ISNULL(j.Cost, 0) AS DECIMAL(18,2)) AS GrossMargin,
        CAST(CASE WHEN ISNULL(j.Revenue, 0) <> 0
                  THEN (j.Revenue - ISNULL(j.Cost, 0)) / j.Revenue
                  ELSE 0 END AS DECIMAL(18,4)) AS GrossMarginPerc,
        CAST(CASE WHEN j.SalesNumber IS NULL
                   OR (ISNULL(j.Revenue, 0) <> 0 AND ISNULL(j.Cost, 0) = 0)
                  THEN 1 ELSE 0 END AS BIT) AS IsUncosted
    FROM InvScope s
    LEFT JOIN InvJournal j ON j.SalesNumber = s.SalesNumber
    LEFT JOIN Payee p ON p.PayeeId = s.ShipId
    ORDER BY s.ShipDate, p.PayeeName, s.SalesNumber;
END
GO
