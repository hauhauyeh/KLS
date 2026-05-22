SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[_postmigration_LegacyPurchaseInventoryTxDetailBillQty_FromPurchaseDetail];
GO

CREATE PROCEDURE [dbo].[_postmigration_LegacyPurchaseInventoryTxDetailBillQty_FromPurchaseDetail]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
    Purpose:
        Correct legacy-transferred purchase inventory journal rows where
        TransactionJournalDetail.BillQty was not posted from PurchaseDetail.BaseFinalQty.

    Business rule:
        For the purchase inventory row only (AccountCode = '@INV'),
        TransactionJournalDetail.BillQty must equal PurchaseDetail.BaseFinalQty
        when TransactionJournalDetail.SourceDetailId = PurchaseDetail.PurchaseDetailId.

    Document coverage:
        This correction covers both normal purchase bills and purchase debit memos.
        The journal header identifies those rows as:
        - TransactionJournal.SourceDocType = 'Purchase'
        - TransactionJournal.SourceDocType = 'Purchase Debit Memo'

    Important notes:
        1. This procedure updates only dbo.TransactionJournalDetail rows.
        2. This procedure targets only purchase bill and purchase debit memo postings.
        3. This procedure targets only the inventory journal row (AccountCode = '@INV').
        4. This procedure does not touch rows that already match PurchaseDetail.BaseFinalQty.
    */

    -- Section 1. Resolve the inventory account that identifies the inventory journal row.
    DECLARE @InventoryAccountId INT;

    SELECT @InventoryAccountId = a.AccountId
    FROM dbo.Account AS a
    WHERE a.AccountCode = '@INV';

    IF @InventoryAccountId IS NULL
    BEGIN
        THROW 50011, 'Inventory account @INV was not found. Cannot continue.', 1;
    END;

    -- Section 2. Build the exact repair scope before any update runs.
    -- This isolates only the inventory journal rows for purchase bills and purchase debit memos
    -- whose journal BillQty does not match the source-of-truth PurchaseDetail.BaseFinalQty.
    IF OBJECT_ID('tempdb..#FixScope') IS NOT NULL
        DROP TABLE #FixScope;

    CREATE TABLE #FixScope
    (
        TxDetailId BIGINT NOT NULL PRIMARY KEY,
        TxId BIGINT NOT NULL,
        SourceDetailId INT NOT NULL,
        SourceDocNumber INT NULL,
        SourceDocType NVARCHAR(100) NULL,
        ItemId INT NULL,
        OldBillQty DECIMAL(18, 6) NULL,
        NewBillQty DECIMAL(18, 6) NULL
    );

    INSERT INTO #FixScope
    (
        TxDetailId,
        TxId,
        SourceDetailId,
        SourceDocNumber,
        SourceDocType,
        ItemId,
        OldBillQty,
        NewBillQty
    )
    SELECT
        td.TxDetailId,
        td.TxId,
        td.SourceDetailId,
        tj.SourceDocNumber,
        tj.SourceDocType,
        td.ItemId,
        td.BillQty,
        pd.BaseFinalQty
    FROM dbo.TransactionJournalDetail AS td
    INNER JOIN dbo.TransactionJournal AS tj
        ON tj.TxId = td.TxId
    INNER JOIN dbo.PurchaseDetail AS pd
        ON pd.PurchaseDetailId = td.SourceDetailId
    WHERE tj.SourceDocType IN ('Purchase', 'Purchase Debit Memo')
      AND td.AccountId = @InventoryAccountId
      AND td.SourceDetailId IS NOT NULL
      AND ISNULL(td.BillQty, 0) <> ISNULL(pd.BaseFinalQty, 0);

    -- Section 3. Preview the candidate rows for reviewer confirmation before update.
    SELECT COUNT(*) AS CandidateRowCount
    FROM #FixScope;

    SELECT TOP (200)
        fs.TxDetailId,
        fs.TxId,
        fs.SourceDetailId,
        fs.SourceDocType,
        fs.SourceDocNumber,
        fs.ItemId,
        fs.OldBillQty,
        fs.NewBillQty
    FROM #FixScope AS fs
    ORDER BY fs.TxDetailId;

    IF NOT EXISTS (SELECT 1 FROM #FixScope)
    BEGIN
        PRINT 'No rows require correction.';
        RETURN;
    END;

    -- Section 4. Prepare an audit snapshot of the rows that this procedure changes.
    IF OBJECT_ID('tempdb..#UpdatedRows') IS NOT NULL
        DROP TABLE #UpdatedRows;

    CREATE TABLE #UpdatedRows
    (
        TxDetailId BIGINT NOT NULL,
        TxId BIGINT NOT NULL,
        SourceDetailId INT NOT NULL,
        SourceDocNumber INT NULL,
        SourceDocType NVARCHAR(100) NULL,
        ItemId INT NULL,
        OldBillQty DECIMAL(18, 6) NULL,
        NewBillQty DECIMAL(18, 6) NULL
    );

    -- Section 5. Apply the correction inside one transaction.
    -- The update changes only BillQty on the targeted inventory journal row.
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE td
        SET td.BillQty = fs.NewBillQty
        OUTPUT
            inserted.TxDetailId,
            inserted.TxId,
            inserted.SourceDetailId,
            fs.SourceDocNumber,
            fs.SourceDocType,
            inserted.ItemId,
            deleted.BillQty,
            inserted.BillQty
        INTO #UpdatedRows
        (
            TxDetailId,
            TxId,
            SourceDetailId,
            SourceDocNumber,
            SourceDocType,
            ItemId,
            OldBillQty,
            NewBillQty
        )
        FROM dbo.TransactionJournalDetail AS td
        INNER JOIN #FixScope AS fs
            ON fs.TxDetailId = td.TxDetailId;

        SELECT @@ROWCOUNT AS UpdatedRowCount;

        -- Section 6. Verify that no purchase bill or purchase debit memo inventory rows remain mismatched.
        SELECT COUNT(*) AS RemainingMismatchCount
        FROM dbo.TransactionJournalDetail AS td
        INNER JOIN dbo.TransactionJournal AS tj
            ON tj.TxId = td.TxId
        INNER JOIN dbo.PurchaseDetail AS pd
            ON pd.PurchaseDetailId = td.SourceDetailId
        WHERE tj.SourceDocType IN ('Purchase', 'Purchase Debit Memo')
          AND td.AccountId = @InventoryAccountId
          AND td.SourceDetailId IS NOT NULL
          AND ISNULL(td.BillQty, 0) <> ISNULL(pd.BaseFinalQty, 0);

        -- Section 7. Return a sample of changed rows so the reviewer can spot-check the result.
        SELECT TOP (200)
            ur.TxDetailId,
            ur.TxId,
            ur.SourceDetailId,
            ur.SourceDocType,
            ur.SourceDocNumber,
            ur.ItemId,
            ur.OldBillQty,
            ur.NewBillQty
        FROM #UpdatedRows AS ur
        ORDER BY ur.TxDetailId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END
GO
