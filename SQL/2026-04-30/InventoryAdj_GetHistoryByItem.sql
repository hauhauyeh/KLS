SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[InventoryAdj_GetHistoryByItem]
    @ItemId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @InventoryAccountId INT;

    -- This lightweight history query is only for the Product List Qty Adj modal.
    -- Keep it item-specific and limited to the 30 most recent rows so the dialog opens quickly.
    SELECT @InventoryAccountId = AccountId
    FROM dbo.Account
    WHERE AccountCode = '@INV';

    ;WITH RecentAdjustment AS (
        SELECT TOP (30)
            a.AdjId,
            ad.AdjDetailId,
            a.AdjNumber,
            a.AdjDate,
            a.AdjType,
            ad.ItemId,
            ad.NewQty,
            ad.NewPrice,
            ad.Notes AS DetailNotes,
            a.Notes,
            i.ItemCode,
            i.ItemName
        FROM dbo.InventoryAdj AS a
        INNER JOIN dbo.InventoryAdjDetail AS ad ON a.AdjId = ad.AdjId
        INNER JOIN dbo.Item AS i ON ad.ItemId = i.ItemId
        WHERE ad.ItemId = @ItemId
        ORDER BY a.AdjDate DESC, a.AdjNumber DESC, ad.AdjDetailId DESC
    ),
    ItemTransaction AS (
        SELECT
            t.SourceDocType,
            t.SourceDocNumber,
            td.ItemId,
            LEAD(td.ClosingQty) OVER (
                PARTITION BY td.ItemId
                ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC
            ) AS QtyBefore,
            LEAD(td.AverageCost) OVER (
                PARTITION BY td.ItemId
                ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC
            ) AS PriceBefore
        FROM dbo.TransactionJournal AS t
        INNER JOIN dbo.TransactionJournalDetail AS td ON t.TxId = td.TxId
        WHERE td.AccountId = @InventoryAccountId
          AND td.ItemId = @ItemId
    )
    SELECT
        CAST(ROW_NUMBER() OVER (ORDER BY ra.AdjDate DESC, ra.AdjNumber DESC, ra.AdjDetailId DESC) AS INT) AS AutoId,
        ra.AdjId,
        ra.AdjDetailId,
        ra.AdjNumber,
        ra.AdjDate,
        ra.AdjType,
        ra.ItemId,
        ra.NewQty,
        ra.NewPrice,
        ra.DetailNotes,
        ra.Notes,
        CAST(NULL AS DATE) AS PrevAdjDate,
        ra.ItemCode,
        ra.ItemName,
        tx.QtyBefore,
        tx.PriceBefore
    FROM RecentAdjustment AS ra
    LEFT JOIN ItemTransaction AS tx
        ON tx.ItemId = ra.ItemId
       AND tx.SourceDocNumber = ra.AdjNumber
       AND tx.SourceDocType IN ('Inventory Adj', 'Inventory Adj Closing')
    ORDER BY AutoId;
END
GO
