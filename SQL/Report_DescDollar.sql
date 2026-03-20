-- Rename existing SP
EXEC sp_rename 'Report_DescDollar', 'Report_DescDollar_prev';
GO

CREATE PROCEDURE [dbo].[Report_DescDollar]
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
            SUM(td.Amount * -1) AS TotalPrice,
            SUM(td.Qty) AS TotalQty
        FROM dbo.TransactionJournal t
        INNER JOIN dbo.TransactionJournalDetail td
            ON t.TxId = td.TxId
        WHERE
            td.PayeeId = ' + CONVERT(VARCHAR, @PayeeId) + '
            AND t.SourceDocType = ''Sales''
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
        ON iu.ItemId = i.ItemId AND iu.IsBaseUnit=1';

    IF @SortField IS NOT NULL
        SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder;
    ELSE
        SET @Qry += ' ORDER BY TotalPrice DESC';

    EXEC (@Qry);
END
GO
