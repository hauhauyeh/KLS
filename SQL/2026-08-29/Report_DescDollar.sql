SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_DescDollar] -- [Report_DescDollar] @PayeeId = 300002, @StartDate = '2026-01-01', @EndDate = '2026-12-31', @SortField = 'TotalPrice', @SortOrder = 'DESC'
(
    @PayeeId   INT,
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL,
    @SortField NVARCHAR(50) = NULL,
    @SortOrder NVARCHAR(50) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    /*
        2026-08-29: Source this customer sales report from Sales/SalesDetail
        instead of @INV ledger rows so non-inventory sold items are included.

        Old basis:
            TransactionJournalDetail @INV rows for SourceDocType = Sales.

        Report remains base-unit based:
            TotalQty   = BaseShipQty
            TotalPrice = saved line ExtTotal, with a defensive fallback for old rows.
    */

    DECLARE @SortFieldSafe NVARCHAR(50) =
        CASE WHEN @SortField IN ('TotalPrice', 'TotalQty', 'ItemName')
             THEN @SortField
             ELSE 'TotalPrice'
        END;

    DECLARE @SortOrderSafe NVARCHAR(4) =
        CASE WHEN UPPER(@SortOrder) = 'ASC'
             THEN 'ASC'
             ELSE 'DESC'
        END;

    ;WITH cte AS
    (
        SELECT
            sd.ItemId,
            SUM(ISNULL(sd.BaseShipQty, 0)) AS TotalQty,
            SUM(ISNULL(sd.ExtTotal, ROUND(ISNULL(sd.ShipQty, 0) * ISNULL(sd.UnitPrice, 0), 2))) AS TotalPrice
        FROM dbo.Sales AS s
        INNER JOIN dbo.SalesDetail AS sd
            ON sd.SalesId = s.SalesId
        WHERE s.ShipId = @PayeeId
          AND s.StageId IN (3, 4)
          AND sd.LineType = 'I'
          AND sd.ItemId IS NOT NULL
          AND (@StartDate IS NULL OR s.ShipDate >= @StartDate)
          AND (@EndDate IS NULL OR s.ShipDate <= @EndDate)
        GROUP BY sd.ItemId
        HAVING SUM(ISNULL(sd.BaseShipQty, 0)) <> 0
            OR SUM(ISNULL(sd.ExtTotal, ROUND(ISNULL(sd.ShipQty, 0) * ISNULL(sd.UnitPrice, 0), 2))) <> 0
    )
    SELECT
        c.ItemId,
        i.ItemName,
        iu.Unit,
        c.TotalQty,
        c.TotalPrice
    FROM cte AS c
    INNER JOIN dbo.Item AS i
        ON i.ItemId = c.ItemId
    INNER JOIN dbo.ItemUnit AS iu
        ON iu.ItemId = i.ItemId
       AND iu.IsBaseUnit = 1
    ORDER BY
        CASE WHEN @SortFieldSafe = 'TotalPrice' AND @SortOrderSafe = 'ASC' THEN c.TotalPrice END ASC,
        CASE WHEN @SortFieldSafe = 'TotalPrice' AND @SortOrderSafe = 'DESC' THEN c.TotalPrice END DESC,
        CASE WHEN @SortFieldSafe = 'TotalQty' AND @SortOrderSafe = 'ASC' THEN c.TotalQty END ASC,
        CASE WHEN @SortFieldSafe = 'TotalQty' AND @SortOrderSafe = 'DESC' THEN c.TotalQty END DESC,
        CASE WHEN @SortFieldSafe = 'ItemName' AND @SortOrderSafe = 'ASC' THEN i.ItemName END ASC,
        CASE WHEN @SortFieldSafe = 'ItemName' AND @SortOrderSafe = 'DESC' THEN i.ItemName END DESC,
        i.ItemName ASC;
END
GO
