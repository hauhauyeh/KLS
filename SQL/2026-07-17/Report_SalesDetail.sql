SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- FIX_ICREDIT_AMOUNT_SIGN 2026-07-17 (reader): Revenue now sums td.CrDeAmount over @ISALE+@ICREDIT
-- instead of td.Amount. For revenue detail rows CrDeAmount = the signed line value under BOTH the
-- old (buggy) and new posting conventions, so this report returns IDENTICAL results before and
-- after the Amount-sign data fix (TxDetail_FixAmountSign_292_310.sql). Without this change, the
-- data fix would flip @ICREDIT Amount to +magnitude and credit-memo lines would ADD to ExtTotal/
-- Margin instead of netting them down. COGS stays on td.Amount -- convention unchanged.
-- See baseline: KLS/SQL/2026-07-17/Report_SalesDetail_live_baseline.sql
CREATE OR ALTER PROCEDURE [dbo].[Report_SalesDetail] -- EXEC Report_SalesDetail @StartDate='2026-06-01',@EndDate='2026-06-26',@ItemCode=NULL,@SalesRep=NULL
-- EXEC Report_SalesDetail @StartDate='2026-06-01',@EndDate='2026-06-26',@ItemCode='CB',@SalesRep=NULL
    @StartDate DATE,
    @EndDate   DATE,
    @ItemCode  NVARCHAR(50),
    @SalesRep  INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ISALE   INT = (SELECT AccountId FROM Account WHERE AccountCode = '@ISALE');
    DECLARE @ICREDIT INT = (SELECT AccountId FROM Account WHERE AccountCode = '@ICREDIT');
    DECLARE @COGS    INT = (SELECT AccountId FROM Account WHERE AccountCode = '@COGS');

    -- 1) In-scope lines (ShipDate / ItemCode / SalesRep). Skip '@'-charge items (not item sales).
    SELECT sd.SalesDetailId, s.SalesId, s.ShipDate, s.SalesRepId,
           i.ItemCode, i.ItemName, sd.UnitPrice, sd.ShipQty, sd.BillQty
    INTO #lines
    FROM Sales s
    JOIN SalesDetail sd ON s.SalesId = sd.SalesId
    JOIN Item i ON i.ItemId = sd.ItemId
    WHERE s.ShipDate BETWEEN @StartDate AND @EndDate
      AND i.ItemCode NOT LIKE '%@%'                      -- skip unrelated (@-charge) lines
      AND (@ItemCode IS NULL OR i.ItemCode = @ItemCode)
      AND (@SalesRep IS NULL OR s.SalesRepId = @SalesRep);
    CREATE CLUSTERED INDEX IX_lines ON #lines (SalesDetailId);

    -- 2) Recognized revenue (@ISALE+@ICREDIT) and cost (@COGS) for EXACTLY those lines, by
    --    SourceDetailId. No journal date filter -- the in-scope line set is the scope.
    SELECT td.SourceDetailId AS SalesDetailId,
           -- 2026-07-17 FIX_ICREDIT_AMOUNT_SIGN: sign-independent revenue (see header).
           -- OLD: SUM(CASE WHEN td.AccountId IN (@ISALE, @ICREDIT) THEN td.Amount ELSE 0 END) AS Revenue,
           SUM(CASE WHEN td.AccountId IN (@ISALE, @ICREDIT) THEN td.CrDeAmount ELSE 0 END) AS Revenue,
           SUM(CASE WHEN td.AccountId = @COGS              THEN td.Amount ELSE 0 END) AS COGS
    INTO #jl
    FROM TransactionJournalDetail td
    JOIN TransactionJournal t ON t.TxId = td.TxId
    WHERE td.AccountId IN (@ISALE, @ICREDIT, @COGS)
      AND t.SourceDocType IN ('Sales', 'Sales Credit Memo')
      AND td.SourceDetailId IN (SELECT SalesDetailId FROM #lines)
    GROUP BY td.SourceDetailId;
    CREATE CLUSTERED INDEX IX_jl ON #jl (SalesDetailId);

    -- 3) Final result -- same output columns + rep grouping. ExtTotal now carries recognized
    --    @ISALE+@ICREDIT revenue (= the line's sale; for product lines this equals the old ExtTotal).
    SELECT
        CAST(ROW_NUMBER() OVER (ORDER BY p.PayeeName, l.ShipDate, l.ItemName) AS INT) AS RowId,
        l.SalesId AS SalesNum,
        l.ShipDate,
        l.ItemCode,
        l.ItemName AS ItemDesc1,
        SUM(l.ShipQty) AS ShipQty,
        SUM(l.BillQty) AS BillQty,
        l.UnitPrice AS Price,
        -- 2026-06-28: recognized revenue @ISALE+@ICREDIT (was SUM(l.ExtTotal))
        SUM(ISNULL(j.Revenue, 0)) AS ExtTotal,
        SUM(ISNULL(j.COGS, 0)) AS Cost,
        SUM(ISNULL(j.Revenue, 0) - ISNULL(j.COGS, 0)) AS Margin,
        p.PayeeName AS SalesRepName
    FROM #lines l
    LEFT JOIN #jl j ON j.SalesDetailId = l.SalesDetailId
    LEFT JOIN Payee p ON p.PayeeId = l.SalesRepId
    GROUP BY l.SalesId, l.ShipDate, l.ItemCode, l.ItemName, p.PayeeName, l.UnitPrice
    ORDER BY p.PayeeName, l.ShipDate, l.ItemName;

    DROP TABLE #lines;
    DROP TABLE #jl;
END

