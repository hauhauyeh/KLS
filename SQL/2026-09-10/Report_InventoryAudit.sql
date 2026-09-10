SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_InventoryAudit] -- EXEC dbo.Report_InventoryAudit @ItemId = 1, @StartDate = '2026-08-01', @EndDate = '2026-08-31', @PayeeId = NULL, @SourceDocType = NULL, @SourceDocNumber = NULL
    @ItemId INT,
    @StartDate DATE,
    @EndDate DATE,
    @PayeeId INT = NULL,
    @SourceDocType NVARCHAR(100) = NULL,
    @SourceDocNumber INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        td.TxDetailId,
        t.TxId,
        t.TxDate,
        t.SourceDocType,
        t.SourceDocNumber,
        s.SalesDocNumber,
        td.PayeeId,
        p.PayeeName,
        CASE
            WHEN t.SourceDocOrder = 500 THEN td.Qty * -1
            WHEN t.SourceDocOrder = 505 THEN ABS(td.Qty)
            ELSE td.Qty
        END AS InventoryQty,
        td.ClosingQty
    FROM dbo.TransactionJournal AS t
    INNER JOIN dbo.TransactionJournalDetail AS td ON td.TxId = t.TxId
    INNER JOIN dbo.Account AS a ON a.AccountId = td.AccountId
    INNER JOIN dbo.Item AS i ON i.ItemId = td.ItemId
    LEFT JOIN dbo.Payee AS p ON p.PayeeId = td.PayeeId
    LEFT JOIN dbo.Sales AS s ON t.SourceDocType = 'Sales'
        AND s.SalesNumber = t.SourceDocNumber
    WHERE a.AccountCode = '@INV'
      AND i.ItemId = @ItemId
      AND t.TxDate >= @StartDate
      AND t.TxDate <= @EndDate
      AND (@PayeeId IS NULL OR td.PayeeId = @PayeeId)
      AND (@SourceDocType IS NULL OR t.SourceDocType = @SourceDocType)
      AND (@SourceDocNumber IS NULL OR t.SourceDocNumber = @SourceDocNumber)
    ORDER BY
        t.TxDate,
        t.SourceDocOrder,
        td.TxDetailId;
END
GO
