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

    -- Recognized double-entry accounts: @ISALE = sales revenue (SO), @ICREDIT = customer credit
    -- (CM revenue side), @COGS = cost of goods sold (both SO and CM, signed).
    -- SCOPE DECISION (2026-06-26, Howard): "Sales" = INVENTORY product revenue only (@ISALE +
    -- @ICREDIT) -- the same scope as the old report's "CountableTotal". Other income that can post
    -- on an invoice (@ICCF credit-card-fee, @IFR freight, @IOT other income; all Revenue-class 'I')
    -- is DELIBERATELY EXCLUDED so margin stays a clean product margin vs @COGS. ~0.06% of revenue
    -- and a handful of invoices/month. Sales tax (@FSTP) is always excluded (not revenue), so by
    -- design Sales = InvoiceTotal - tax - other-income, and does NOT reconcile to InvoiceTotal.
    DECLARE @ISALE   INT = (SELECT AccountId FROM Account WHERE AccountCode = '@ISALE');
    DECLARE @ICREDIT INT = (SELECT AccountId FROM Account WHERE AccountCode = '@ICREDIT');
    DECLARE @COGS    INT = (SELECT AccountId FROM Account WHERE AccountCode = '@COGS');

    ;WITH InvScope AS
    (
        -- invoices shipped in the window -- this is the report's date meaning
        SELECT s.SalesId, s.SalesNumber, s.ShipDate, s.ShipRoute, s.DocType,
               s.ParentSalesNumber, s.ShipId, s.SalesRepId, s.SalesTotal
        FROM Sales s
        WHERE s.ShipDate BETWEEN @StartDate AND @EndDate
          AND s.SalesRepId = CASE WHEN @SalesRep IS NOT NULL THEN @SalesRep ELSE s.SalesRepId END
    ),
    InvJournal AS
    (
        -- per-invoice posted revenue/cost, bounded to in-scope invoices for speed.
        -- Revenue = @ISALE (SO) + @ICREDIT (CM); both doc types scanned so CMs aren't missed.
        SELECT t.SourceDocNumber AS SalesNumber,
               -- 2026-07-17 FIX_ICREDIT_AMOUNT_SIGN: sign-independent revenue (see header).
               -- OLD: ISNULL(SUM(CASE WHEN td.AccountId IN (@ISALE, @ICREDIT) THEN td.Amount END), 0) AS Revenue,
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
        s.ShipDate,
        s.ShipRoute,
        s.DocType,
        s.ParentSalesNumber,
        s.ShipId,                            -- stable key for the UI customer-name dedup
        p.PayeeName AS Customer,
        s.SalesRepId,
        CAST(s.SalesTotal AS DECIMAL(18,2)) AS InvoiceTotal,
        CAST(ISNULL(j.Revenue, 0) AS DECIMAL(18,2)) AS Amount,        -- recognized revenue (@ISALE + @ICREDIT)
        CAST(ISNULL(j.Cost, 0)    AS DECIMAL(18,2)) AS Cost,          -- recognized cost (@COGS)
        CAST(ISNULL(j.Revenue, 0) - ISNULL(j.Cost, 0) AS DECIMAL(18,2)) AS GrossMargin,
        CAST(CASE WHEN ISNULL(j.Revenue, 0) <> 0
                  THEN (j.Revenue - ISNULL(j.Cost, 0)) / j.Revenue
                  ELSE 0 END AS DECIMAL(18,4)) AS GrossMarginPerc,
        -- uncosted = journal not posted yet (LEFT JOIN miss), OR revenue booked with zero cost
        CAST(CASE WHEN j.SalesNumber IS NULL
                   OR (ISNULL(j.Revenue, 0) <> 0 AND ISNULL(j.Cost, 0) = 0)
                  THEN 1 ELSE 0 END AS BIT) AS IsUncosted
    FROM InvScope s
    LEFT JOIN InvJournal j ON j.SalesNumber = s.SalesNumber   -- LEFT: keep shipped-but-unposted invoices
    LEFT JOIN Payee p ON p.PayeeId = s.ShipId
    ORDER BY s.ShipDate, p.PayeeName, s.SalesNumber;
END

