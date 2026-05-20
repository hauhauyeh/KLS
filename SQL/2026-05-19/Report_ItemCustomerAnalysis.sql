-- ============================================================================
-- Report_ItemCustomerAnalysis  (2026-05-19)
-- Per-customer aggregate for a single item over a date range.
-- One row per (item, customer); ordered by sales amount DESC.
-- Drives the new Item Customer Analysis report.
--
-- Cost source: TransactionJournalDetail filtered to @COGS account.
-- SalesDetail.FIFOCost is rarely populated on shipped lines, so we read the
-- recognized cost from the journal -- the same pattern Report_CustSalesbyItem
-- uses. Qty comes from the @INV line so it reflects base-unit movement;
-- Amount comes from the @ISALE line so it reflects the recognized sale net.
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_NULLS ON;
GO

DROP PROCEDURE IF EXISTS dbo.Report_ItemCustomerAnalysis;
GO

CREATE PROCEDURE [dbo].[Report_ItemCustomerAnalysis]
    @ItemId    INT,
    @PayeeId   INT  = NULL,
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Default window: trailing 12 months ending today.
    IF @EndDate   IS NULL SET @EndDate   = CAST(GETDATE() AS DATE);
    IF @StartDate IS NULL SET @StartDate = DATEADD(MONTH, -11, DATEFROMPARTS(YEAR(@EndDate), MONTH(@EndDate), 1));

    DECLARE @INVAccountId   INT = (SELECT AccountId FROM dbo.Account WHERE AccountCode = '@INV');
    DECLARE @ISALEAccountId INT = (SELECT AccountId FROM dbo.Account WHERE AccountCode = '@ISALE');
    DECLARE @COGSAccountId  INT = (SELECT AccountId FROM dbo.Account WHERE AccountCode = '@COGS');

    ;WITH cte AS
    (
        SELECT
            td.PayeeId,
            Qty        = SUM(CASE WHEN td.AccountId = @INVAccountId   THEN td.Qty    ELSE 0 END),
            Amount     = SUM(CASE WHEN td.AccountId = @ISALEAccountId THEN td.Amount ELSE 0 END),
            Cost       = SUM(CASE WHEN td.AccountId = @COGSAccountId  THEN td.Amount ELSE 0 END),
            LastTxDate = MAX(t.TxDate)
        FROM dbo.TransactionJournal       t
        INNER JOIN dbo.TransactionJournalDetail td ON td.TxId = t.TxId
        WHERE t.SourceDocType = 'Sales'
          AND td.ItemId  = @ItemId
          AND t.TxDate  >= @StartDate
          AND t.TxDate   < DATEADD(DAY, 1, @EndDate)
          AND (@PayeeId IS NULL OR td.PayeeId = @PayeeId)
        GROUP BY td.PayeeId
    )
    SELECT
        c.PayeeId,
        p.PayeeName,
        QtySold       = ISNULL(c.Qty, 0),
        SalesAmount   = ISNULL(c.Amount, 0),
        AvgPrice      = CASE WHEN ISNULL(c.Qty, 0) = 0 THEN 0
                             ELSE c.Amount / c.Qty END,
        TotalCost     = ISNULL(c.Cost, 0),
        MarginPercent = CASE WHEN ISNULL(c.Amount, 0) = 0 THEN NULL
                             ELSE (c.Amount - ISNULL(c.Cost, 0)) * 100.0 / c.Amount END,
        LastPurchase  = CAST(c.LastTxDate AS DATE),
        DaysSinceLast = DATEDIFF(DAY, c.LastTxDate, CAST(GETDATE() AS DATE))
    FROM cte         c
    INNER JOIN dbo.Payee p ON p.PayeeId = c.PayeeId
    WHERE c.Qty <> 0
    ORDER BY c.Amount DESC;
END
GO
