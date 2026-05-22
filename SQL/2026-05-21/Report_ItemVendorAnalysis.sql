SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- First-round SP — no _prev rename needed (SP doesn't exist yet).
DROP PROCEDURE IF EXISTS [dbo].[Report_ItemVendorAnalysis];
GO

CREATE PROCEDURE [dbo].[Report_ItemVendorAnalysis]
    @ItemId    INT,
    @PayeeId   INT  = NULL,
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    /*
      Item Vendor Analysis — for one item, per-vendor purchase aggregates.

      AP-side mirror of Report_ItemCustomerAnalysis. Two structural differences:
        1. SourceDocType = 'Purchase' instead of 'Sales'.
        2. Only the @INV account row is summed (no @ISALE/@COGS split — Purchase
           debits @INV with the inventory value; no sell-side, so no margin
           column).

      Adds PercentOfSpend column via window function over the per-item total.
    */

    -- Default window: trailing 12 months ending today.
    IF @EndDate   IS NULL SET @EndDate   = CAST(GETDATE() AS DATE);
    IF @StartDate IS NULL SET @StartDate = DATEADD(MONTH, -11, DATEFROMPARTS(YEAR(@EndDate), MONTH(@EndDate), 1));

    DECLARE @INVAccountId INT = (SELECT AccountId FROM dbo.Account WHERE AccountCode = '@INV');

    ;WITH cte AS
    (
        SELECT
            td.PayeeId,
            QtyPurchased = SUM(td.Qty),
            TotalCost    = SUM(td.Amount),
            LastTxDate   = MAX(t.TxDate)
        FROM dbo.TransactionJournal       t
        INNER JOIN dbo.TransactionJournalDetail td ON td.TxId = t.TxId
        WHERE t.SourceDocType = 'Purchase'
          AND td.ItemId    = @ItemId
          AND td.AccountId = @INVAccountId
          AND t.TxDate    >= @StartDate
          AND t.TxDate     < DATEADD(DAY, 1, @EndDate)
          AND (@PayeeId IS NULL OR td.PayeeId = @PayeeId)
        GROUP BY td.PayeeId
    )
    SELECT
        c.PayeeId,
        p.PayeeName,
        QtyPurchased   = ISNULL(c.QtyPurchased, 0),
        TotalCost      = ISNULL(c.TotalCost, 0),
        AvgUnitCost    = CASE WHEN ISNULL(c.QtyPurchased, 0) = 0 THEN 0
                              ELSE c.TotalCost / c.QtyPurchased END,
        PercentOfSpend = CASE WHEN SUM(c.TotalCost) OVER () = 0 THEN 0
                              ELSE c.TotalCost * 100.0 / SUM(c.TotalCost) OVER () END,
        LastPurchase   = CAST(c.LastTxDate AS DATE),
        DaysSinceLast  = DATEDIFF(DAY, c.LastTxDate, CAST(GETDATE() AS DATE))
    FROM cte         c
    INNER JOIN dbo.Payee p ON p.PayeeId = c.PayeeId
    WHERE c.QtyPurchased <> 0
    ORDER BY c.TotalCost DESC;
END
GO
