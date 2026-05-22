SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[_exam_tx_inventory];
GO

CREATE PROCEDURE [dbo].[_exam_tx_inventory]
    @ItemCode NVARCHAR(100) = NULL,
    @FromDate DATE = '2024-01-01',
    @OnlyInv BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    /*
    Purpose:
        Simple exam procedure to inspect inventory posting rows.

    Default behavior:
        - floor date starts at 2024-01-01
        - pass ItemCode
        - default shows only @INV rows
        - set @OnlyInv = 0 to show all matched account rows

    Execution examples:
        EXEC dbo._exam_tx_inventory @ItemCode = 'YOUR-ITEM-CODE';
        EXEC dbo._exam_tx_inventory @ItemCode = 'YOUR-ITEM-CODE', @OnlyInv = 0;
    */

    DECLARE @ItemId INT;
    DECLARE @InvAccountId INT;

    IF ISNULL(LTRIM(RTRIM(@ItemCode)), '') = ''
    BEGIN
        THROW 50001, 'ItemCode is required.', 1;
    END;

    SELECT @InvAccountId = AccountId
    FROM dbo.Account
    WHERE AccountCode = '@INV';

    IF @InvAccountId IS NULL
    BEGIN
        THROW 50002, 'AccountCode @INV was not found.', 1;
    END;

    SELECT @ItemId = ItemId
    FROM dbo.Item
    WHERE ItemCode = @ItemCode;

    IF @ItemId IS NULL
    BEGIN
        THROW 50003, 'The requested ItemCode was not found.', 1;
    END;

    SELECT
        t.TxId,
        t.TxDate,
        t.SourceDocType,
        t.SourceDocNumber,
        td.TxDetailId,
        td.AccountId,
        a.AccountName,
        td.Qty,
        td.Price,
        td.BillQty,
        td.FactorToBase,
        td.ClosingQty,
        td.AverageCost,
        td.InventoryValue,
        td.Amount,
        td.CrDeAmount,
        ROUND(td.ClosingQty * td.AverageCost, 6) AS NewInvValue
    FROM dbo.TransactionJournal t
    INNER JOIN dbo.TransactionJournalDetail td
        ON t.TxId = td.TxId
    INNER JOIN dbo.Account a
        ON a.AccountId = td.AccountId
    WHERE t.TxDate >= @FromDate
      AND td.ItemId = @ItemId
      AND
      (
            @OnlyInv = 0
         OR td.AccountId = @InvAccountId
      )
    ORDER BY t.TxDate, t.SourceDocOrder, td.TxDetailId;

    -- Historical quick test example kept as comment:
    -- declare @cloqty money
    -- declare @avgcost money
    -- declare @invvalue money
    -- exec [RecalcQAV] 1654,'05/04/2026',@cloqty output,@avgcost output,@invvalue output
END
GO
