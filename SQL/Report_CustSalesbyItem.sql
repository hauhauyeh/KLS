-- Report_CustSalesbyItem — Customer sales by item with qty, amount, cost, margin
-- Adapted from legacy SP for KLS_Latest schema
CREATE PROCEDURE [dbo].[Report_CustSalesbyItem]
    @Search NVARCHAR(100) = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL,
    @Grpbycat BIT = 0,
    @Sortby NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalSales MONEY;
    DECLARE @INVAccountId INT;
    DECLARE @ISALEAccountId INT;
    DECLARE @COGSAccountId INT;

    SELECT @INVAccountId = AccountId FROM Account WHERE AccountCode = '@INV';
    SELECT @ISALEAccountId = AccountId FROM Account WHERE AccountCode = '@ISALE';
    SELECT @COGSAccountId = AccountId FROM Account WHERE AccountCode = '@COGS';

    ;WITH ctecust AS (
        SELECT p.PayeeId
        FROM Payee AS p
        WHERE (@Search IS NULL OR p.PayeeName LIKE '%' + @Search + '%' OR CAST(p.PayeeId AS VARCHAR) LIKE '%' + @Search + '%')
          AND p.PayeeType = 'c'
    ),
    cte AS (
        SELECT
            td.ItemId,
            td.PayeeId,
            SUM(CASE WHEN td.AccountId = @INVAccountId THEN td.Qty ELSE 0 END) AS Qty,
            SUM(CASE WHEN td.AccountId = @ISALEAccountId THEN td.Amount ELSE 0 END) AS Amount,
            SUM(CASE WHEN td.AccountId = @COGSAccountId THEN td.Amount ELSE 0 END) AS Cost
        FROM TransactionJournal AS t
        INNER JOIN TransactionJournalDetail AS td ON t.TxId = td.TxId
        INNER JOIN ctecust AS c ON td.PayeeId = c.PayeeId
        WHERE t.SourceDocType = 'Sales'
          AND (@StartDate IS NULL OR t.TxDate >= @StartDate)
          AND (@EndDate IS NULL OR t.TxDate <= @EndDate)
        GROUP BY td.ItemId, td.PayeeId
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY p.PayeeName, i.ItemName) AS AutoId,
        c.PayeeId,
        p.PayeeName,
        i.ItemCode,
        i.ItemName,
        v.Cat0,
        v.Cat1,
        v.Sort0,
        v.Sort1,
        c.Qty,
        c.Amount,
        CAST(0 AS MONEY) AS SalesPerc,
        CASE WHEN c.Qty <> 0 THEN c.Amount / c.Qty ELSE 0 END AS AvgPrice,
        c.Cost,
        CASE WHEN c.Qty <> 0 THEN c.Cost / c.Qty ELSE 0 END AS AvgCost,
        (c.Amount - c.Cost) AS GrossMargin,
        CASE WHEN c.Amount <> 0 THEN (c.Amount - c.Cost) / c.Amount ELSE 0 END AS GrossMarginPerc
    INTO #Result
    FROM cte c
    INNER JOIN Item i ON c.ItemId = i.ItemId
    INNER JOIN Payee p ON c.PayeeId = p.PayeeId
    LEFT JOIN View_Category v ON v.CategoryId = i.CategoryId
    WHERE c.Qty <> 0;

    SELECT @TotalSales = SUM(Amount) FROM #Result;

    UPDATE #Result
    SET SalesPerc = CASE WHEN @TotalSales <> 0 THEN Amount / @TotalSales ELSE 0 END;

    SELECT AutoId, PayeeId, PayeeName, ItemCode, ItemName, Cat0, Cat1,
           Qty, Amount, SalesPerc, AvgPrice, Cost, AvgCost, GrossMargin, GrossMarginPerc
    FROM #Result
    ORDER BY
        PayeeName,
        CASE WHEN @Grpbycat = 1 OR @Sortby IS NULL THEN Sort0 END,
        CASE WHEN @Grpbycat = 1 OR @Sortby IS NULL THEN Sort1 END,
        CASE WHEN @Sortby = 'desc' THEN ItemName END,
        CASE WHEN @Sortby = 'qty' THEN Qty END DESC,
        CASE WHEN @Sortby = 'perc' THEN SalesPerc END DESC,
        ItemName;

    DROP TABLE #Result;
END
