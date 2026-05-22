SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- First-round SP — no _prev rename needed (SP doesn't exist yet).
DROP PROCEDURE IF EXISTS [dbo].[Report_VendorDescDollar];
GO

CREATE PROCEDURE [dbo].[Report_VendorDescDollar]
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
      Vendor Descending Dollar — top items purchased from this vendor by spend.

      Mirror of Report_DescDollar (customer side) with two swaps:
        1. SourceDocType = 'Purchase' instead of 'Sales'.
        2. No sign flip on td.Amount. Purchase debits @INV (positive amount);
           Sales credits @INV (negative amount, hence the * -1 on the customer side).

      Source: TransactionJournalDetail rows posted to @INV with ItemId set,
      filtered by the vendor's PayeeId. Aggregates per ItemId.
    */

    DECLARE @Qry NVARCHAR(MAX);

    DECLARE @InvAccountId INT;

    SELECT
        @InvAccountId = AccountId
    FROM Account
    WHERE AccountCode = '@INV';

    SET @Qry = '
    ;WITH cte AS
    (
        SELECT
            td.ItemId,
            SUM(td.Amount) AS TotalPrice,
            SUM(td.Qty)    AS TotalQty
        FROM dbo.TransactionJournal t
        INNER JOIN dbo.TransactionJournalDetail td
            ON t.TxId = td.TxId
        WHERE
            td.PayeeId = ' + CONVERT(VARCHAR, @PayeeId) + '
            AND t.SourceDocType = ''Purchase''
            AND td.ItemId IS NOT NULL
            AND td.AccountId = ' + CONVERT(VARCHAR, @InvAccountId);

    IF @StartDate IS NOT NULL
        SET @Qry += '
            AND t.TxDate BETWEEN '''
            + CONVERT(VARCHAR, @StartDate, 101) + '''
            AND '''
            + CONVERT(VARCHAR, @EndDate, 101) + '''';

    SET @Qry += '
        GROUP BY td.ItemId
    )
    SELECT
        c.ItemId,
        i.ItemName,
        iu.Unit,
        c.TotalQty,
        c.TotalPrice
    FROM cte c
    INNER JOIN dbo.Item i
        ON i.ItemId = c.ItemId
    INNER JOIN ItemUnit iu
        ON iu.ItemId = i.ItemId AND iu.IsBaseUnit = 1';

    IF @SortField IS NOT NULL
        SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder;
    ELSE
        SET @Qry += ' ORDER BY TotalPrice DESC';

    EXEC (@Qry);
END
GO
