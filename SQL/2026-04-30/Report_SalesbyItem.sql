-- Report_SalesbyItem — Sales by item (all customers) with qty, amount, cost, margin
-- Fixed JOIN bug: s.ItemId = i.ItemId (was i.ItemCode)
CREATE PROCEDURE [dbo].[Report_SalesbyItem]
(
    @Search     NVARCHAR(100) = NULL,
    @StartDate  DATE = NULL,
    @EndDate    DATE = NULL,
    @Grpbycat   BIT = 0,
    @Sortby     NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TotalSales DECIMAL(18,2);
    DECLARE @INVAccountId INT;
    DECLARE @ISALEAccountId INT;
    DECLARE @COGSAccountId INT;

    SELECT @INVAccountId = AccountId FROM Account WHERE AccountCode = '@INV';
    SELECT @ISALEAccountId = AccountId FROM Account WHERE AccountCode = '@ISALE';
    SELECT @COGSAccountId = AccountId FROM Account WHERE AccountCode = '@COGS';

    ;WITH SalesCTE AS
    (
        SELECT
            td.ItemId,
            SUM(CASE WHEN td.AccountId = @INVAccountId   THEN td.Qty    ELSE 0 END) AS Qty,
            SUM(CASE WHEN td.AccountId = @ISALEAccountId THEN td.Amount ELSE 0 END) AS Amount,
            SUM(CASE WHEN td.AccountId = @COGSAccountId  THEN td.Amount ELSE 0 END) AS Cost
        FROM TransactionJournal t
        INNER JOIN TransactionJournalDetail td ON t.TxId = td.TxId
        WHERE
            t.SourceDocType = 'Sales'
            AND (@StartDate IS NULL OR t.TxDate >= @StartDate)
            AND (@EndDate   IS NULL OR t.TxDate <= @EndDate)
        GROUP BY td.ItemId
    )

    SELECT
        i.CategoryId AS Cat,
        s.ItemId,
        i.ItemName,
        v.Cat0,
        v.Cat1,
        v.Sort0,
        v.Sort1,
        s.Qty,
        s.Amount,
        CAST(0 AS MONEY) AS SalesPerc,
        s.Cost,
        (s.Amount - s.Cost) AS GrossMargin,
        CASE WHEN s.Amount <> 0
             THEN (s.Amount - s.Cost) / s.Amount
             ELSE 0 END AS GrossMarginPerc
    INTO #Result
    FROM SalesCTE s
    INNER JOIN Item i ON s.ItemId = i.ItemId
    LEFT JOIN View_Category v ON v.CategoryId = i.CategoryId
    WHERE
        s.Qty <> 0
        AND (@Search IS NULL OR i.ItemName LIKE '%' + @Search + '%');

    SELECT @TotalSales = SUM(Amount) FROM #Result;

    UPDATE #Result
    SET SalesPerc = CASE
                        WHEN @TotalSales <> 0
                        THEN Amount / @TotalSales
                        ELSE 0
                    END;

    SELECT *
    FROM #Result
    ORDER BY
        CASE WHEN @Grpbycat = 1 THEN Sort0 END,
        CASE WHEN @Grpbycat = 1 THEN Sort1 END,
        CASE WHEN @Sortby = 'qty'  THEN Qty END DESC,
        CASE WHEN @Sortby = 'perc' THEN SalesPerc END DESC,
        ItemName;

    DROP TABLE #Result;
END
