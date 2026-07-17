SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- FIX_ICREDIT_AMOUNT_SIGN 2026-07-17 (reader): Revenue now sums td.CrDeAmount over @ISALE+@ICREDIT
-- instead of td.Amount. For revenue detail rows CrDeAmount = the signed line value under BOTH the
-- old (buggy) and new posting conventions, so this report returns IDENTICAL results before and
-- after the Amount-sign data fix (TxDetail_FixAmountSign_292_310.sql). Without this change, the
-- data fix would flip @ICREDIT Amount to +magnitude and credit memos would ADD to commissionable
-- revenue instead of netting it down. Cost (@COGS) stays on td.Amount -- convention unchanged.
-- See baseline: KLS/SQL/2026-07-17/Report_SalesCommission3_live_baseline.sql
CREATE OR ALTER PROCEDURE [dbo].[Report_SalesCommission3] -- EXEC Report_SalesCommission3 @StartDate='2026-04-01',@EndDate='2026-04-30',@SalesRep=NULL
-- EXEC Report_SalesCommission3 @StartDate='2026-04-01',@EndDate='2026-04-30',@SalesRep=123
    @StartDate DATE,
    @EndDate   DATE,
    @SalesRep  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ISALE   INT = (SELECT AccountId FROM Account WHERE AccountCode = '@ISALE');
    DECLARE @ICREDIT INT = (SELECT AccountId FROM Account WHERE AccountCode = '@ICREDIT');
    DECLARE @COGS    INT = (SELECT AccountId FROM Account WHERE AccountCode = '@COGS');

    -- 1) Paid invoices in the window, materialized once and indexed. Settled by a non-CM payment
    --    in [@StartDate,@EndDate], fully paid (AmountDue=0), optional rep filter, and carrying at
    --    least one real (non-@) inventory line (matches v2's scope). DiscountApplied is the
    --    payment-time discount we net from commissionable revenue.
    SELECT s.SalesId, s.SalesNumber, s.ShipDate, s.ShipId, s.SalesRepId, s.SalesTotal,
           ISNULL(s.DiscountApplied, 0) AS DiscountApplied
    INTO #paid
    FROM Sales s
    WHERE s.AmountDue = 0
      AND s.SalesRepId = CASE WHEN @SalesRep IS NOT NULL THEN @SalesRep ELSE s.SalesRepId END
      AND EXISTS (SELECT 1 FROM CustomerPaymentDetail pd
                  JOIN CustomerPayment cp ON cp.CustomerPaymentId = pd.CustomerPaymentId
                  WHERE pd.SalesId = s.SalesId AND pd.IsCreditMemo = 0
                    AND cp.PaymentDate BETWEEN @StartDate AND @EndDate)
      AND EXISTS (SELECT 1 FROM SalesDetail sd JOIN Item i ON i.ItemId = sd.ItemId
                  WHERE sd.SalesId = s.SalesId AND i.ItemCode NOT LIKE '%@%');

    CREATE CLUSTERED INDEX IX_paid ON #paid (SalesNumber);

    -- 2) Per-invoice posted revenue/cost, bounded by JOIN to #paid (clean seeks on TxId)
    SELECT t.SourceDocNumber AS SalesNumber,
           -- 2026-07-17 FIX_ICREDIT_AMOUNT_SIGN: sign-independent revenue (see header).
           -- OLD: ISNULL(SUM(CASE WHEN td.AccountId IN (@ISALE, @ICREDIT) THEN td.Amount END), 0) AS Revenue,
           ISNULL(SUM(CASE WHEN td.AccountId IN (@ISALE, @ICREDIT) THEN td.CrDeAmount END), 0) AS Revenue,
           ISNULL(SUM(CASE WHEN td.AccountId = @COGS THEN td.Amount END), 0) AS Cost
    INTO #j
    FROM TransactionJournal t
    JOIN TransactionJournalDetail td ON td.TxId = t.TxId
    JOIN #paid p ON p.SalesNumber = t.SourceDocNumber
    WHERE t.SourceDocType IN ('Sales', 'Sales Credit Memo')
    GROUP BY t.SourceDocNumber;

    CREATE CLUSTERED INDEX IX_j ON #j (SalesNumber);

    -- 3) Final result. NetRevenue = journal (@ISALE+@ICREDIT) MINUS the payment-time discount.
    SELECT
        CAST(ROW_NUMBER() OVER (ORDER BY rep.PayeeName, cust.PayeeName, p.ShipDate) AS INT) AS Id,
        p.SalesRepId,
        rep.PayeeName  AS SalesRepName,
        p.SalesNumber  AS SalesNum,
        p.ShipId,
        cust.PayeeName AS PayeeName,
        p.ShipDate,
        CAST(p.SalesTotal AS DECIMAL(18,2)) AS SalesTotal,
        CAST(ISNULL(j.Revenue, 0) - p.DiscountApplied AS DECIMAL(18,2)) AS CountableTotal,
        CAST(ISNULL(j.Cost, 0) AS DECIMAL(18,2)) AS CostTotal,
        CAST(CASE WHEN (ISNULL(j.Revenue, 0) - p.DiscountApplied) <> 0
                  THEN ((ISNULL(j.Revenue, 0) - p.DiscountApplied) - ISNULL(j.Cost, 0))
                       / (ISNULL(j.Revenue, 0) - p.DiscountApplied)
                  ELSE 0 END AS DECIMAL(18,4)) AS Margin
    FROM #paid p
    LEFT JOIN #j j ON j.SalesNumber = p.SalesNumber
    LEFT JOIN Payee rep  ON rep.PayeeId  = p.SalesRepId
    LEFT JOIN Payee cust ON cust.PayeeId = p.ShipId
    ORDER BY rep.PayeeName, cust.PayeeName, p.ShipDate;

    DROP TABLE #paid;
    DROP TABLE #j;
END

