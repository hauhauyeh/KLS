SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[InventoryAdj_GetAllList]
    @Pageno INT,
    @Pagesize INT,
    @Search NVARCHAR(100),
    @StartDate DATE,
    @EndDate DATE,
    @Id INT,
    @SortField NVARCHAR(50),
    @SortOrder NVARCHAR(50),
    @IsCount BIT,
    @TotalCount INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);
    DECLARE @AccountId INT;

    CREATE TABLE #InvTable (
        AutoId INT IDENTITY(1,1) NOT NULL,
        AdjId INT NOT NULL,
        AdjDetailId INT,
        AdjNumber INT,
        AdjDate DATE,
        AdjType NVARCHAR(50),
        ItemId INT,
        NewQty DECIMAL(18,2),
        NewPrice DECIMAL(18,2),
        DetailNotes NVARCHAR(255),
        Notes NVARCHAR(255),
        PrevAdjDate DATE,
        ItemCode NVARCHAR(50),
        ItemName NVARCHAR(255),
        QtyBefore DECIMAL(18,2),
        PriceBefore DECIMAL(18,2)
    );

    IF @IsCount = 1
    BEGIN
        SET @Qry = 'SELECT @RCount=COUNT(*)';
    END
    ELSE
    BEGIN
        SET @Qry = 'SELECT a.AdjId,
            ad.AdjDetailId,
            a.AdjNumber,
            a.AdjDate,
            a.AdjType,
            ad.ItemId,
            ad.NewQty,
            ad.NewPrice,
            ad.Notes,
            a.Notes,
            LAG(AdjDate) OVER (PARTITION BY ItemId ORDER BY AdjDate) AS PrevAdjDate';
    END;

    SET @Qry += ' FROM InventoryAdj AS a INNER JOIN InventoryAdjDetail AS ad ON a.AdjId = ad.AdjId WHERE 1=1';

    IF @Id IS NOT NULL
    BEGIN
        SET @Qry += ' AND a.AdjId=' + CONVERT(VARCHAR, @Id) + ' ';
    END;

    IF @Search IS NOT NULL
    BEGIN
        SET @Search = REPLACE(@Search, '''', '''''');
        SET @Qry += ' AND ad.ItemId=''' + @Search + ''' ';
    END;

    IF @StartDate IS NOT NULL
    BEGIN
        SET @Qry += ' AND AdjDate>=''' + CONVERT(VARCHAR, @StartDate) + '''';
    END;

    IF @EndDate IS NOT NULL
    BEGIN
        SET @Qry += ' AND AdjDate<=''' + CONVERT(VARCHAR, @EndDate) + '''';
    END;

    IF @IsCount = 1
    BEGIN
        EXEC sp_executesql @Qry, N'@RCount int OUTPUT', @RCount = @TotalCount OUTPUT;
        RETURN;
    END;

    IF @SortField IS NOT NULL
    BEGIN
        SET @Qry += ' ORDER BY ' + @SortField + ' ' + @SortOrder + '';
    END
    ELSE
    BEGIN
        SET @Qry += ' ORDER BY AdjDate DESC,AdjNumber DESC';
    END;

    SET @Qry += ' OFFSET ' + CONVERT(VARCHAR(100), (@PageSize * (@Pageno - 1))) + ' ROWS
        FETCH NEXT ' + CONVERT(VARCHAR(100), @Pagesize) + ' ROWS ONLY ';

    INSERT INTO #InvTable (
        AdjId,
        AdjDetailId,
        AdjNumber,
        AdjDate,
        AdjType,
        ItemId,
        NewQty,
        NewPrice,
        DetailNotes,
        Notes,
        PrevAdjDate
    )
    EXEC (@Qry);

    UPDATE m
    SET
        m.ItemName = i.ItemName,
        m.ItemCode = i.ItemCode
    FROM #InvTable AS m
    INNER JOIN dbo.Item AS i ON m.ItemId = i.ItemId;

    SELECT @AccountId = AccountId
    FROM dbo.Account
    WHERE AccountCode = '@INV';

    -- QtyBefore and PriceBefore show the inventory state immediately before each adjustment row.
    -- Even though each list row only needs one previous inventory row, SQL Server must know the
    -- full item transaction order to identify that previous row correctly.
    --
    -- Do not filter this CTE to only SourceDocOrder 600/695. Those are the adjustment rows, but
    -- the previous inventory state can come from a purchase, sale, return, opening balance, or
    -- another adjustment. Filtering to only adjustment rows would be faster but would return the
    -- previous adjustment, not the true previous inventory state.
    --
    -- This page can include many different items. The CTE below calculates the ordered inventory
    -- history for the items on the current page, then joins the matching adjustment rows back to
    -- #InvTable. The supporting index
    -- IX_TransactionJournalDetail_AccountId_ItemId_TxId_History helps SQL Server find the relevant
    -- inventory rows by account and item before it applies the TxDate/SourceDocOrder/TxDetailId order.
    --
    -- Tested alternatives:
    -- - OUTER APPLY TOP (1) per adjustment row matched the output but was slower.
    -- - A scoped-window rewrite matched the output but was also slower.
    -- Keep this set-based window version unless a future execution plan proves a better shape.

    ;WITH CTE_Qty AS (
        SELECT
            t.TxId,
            t.SourceDocType,
            td.ItemId,
            t.SourceDocNumber,
            LEAD(td.ClosingQty) OVER (
                PARTITION BY td.ItemId
                ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC
            ) AS PrevQty,
            LEAD(td.AverageCost) OVER (
                PARTITION BY td.ItemId
                ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC
            ) AS PrevCost
        FROM dbo.TransactionJournal AS t
        INNER JOIN dbo.TransactionJournalDetail AS td ON t.TxId = td.TxId
        WHERE td.AccountId = @AccountId
          AND td.ItemId IN (SELECT ItemId FROM #InvTable)
    )
    UPDATE m
    SET
        m.QtyBefore = c.PrevQty,
        m.PriceBefore = c.PrevCost
    FROM #InvTable AS m
    INNER JOIN CTE_Qty AS c
        ON c.ItemId = m.ItemId
       AND m.AdjNumber = c.SourceDocNumber
    WHERE c.SourceDocType IN ('Inventory Adj', 'Inventory Adj Closing');

    SELECT *
    FROM #InvTable
    ORDER BY AutoId;

    DROP TABLE #InvTable;
END
GO
