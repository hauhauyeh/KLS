SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[InventoryAdj_DeleteDetail]
    @AdjDetailId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AdjNumber INT;
    DECLARE @AdjId INT;
    DECLARE @DetailCount INT;
    DECLARE @AdjType NVARCHAR(50);
    DECLARE @TxId BIGINT;
    DECLARE @TxDate DATE;
    DECLARE @ItemId INT;

    -- Find the adjustment header and item behind the requested detail row.
    SELECT
        @AdjId = iad.AdjId,
        @ItemId = iad.ItemId
    FROM dbo.InventoryAdjDetail AS iad
    WHERE iad.AdjDetailId = @AdjDetailId;

    -- Load the adjustment number and adjustment type from the header.
    SELECT
        @AdjNumber = ia.AdjNumber,
        @AdjType = ia.AdjType
    FROM dbo.InventoryAdj AS ia
    WHERE ia.AdjId = @AdjId;

    -- Find the journal header for either supported inventory adjustment timing.
    -- "After Receiving" rows post as Inventory Adj Closing, so this delete path
    -- must support both source document types.
    SELECT
        @TxId = tj.TxId,
        @TxDate = tj.TxDate
    FROM dbo.TransactionJournal AS tj
    WHERE tj.SourceDocNumber = @AdjNumber
      AND tj.SourceDocType IN ('Inventory Adj', 'Inventory Adj Closing');

    -- Stop immediately if the journal header cannot be found.
    -- Deleting the adjustment detail without deleting the matching journal detail
    -- would leave inventory and accounting data out of sync.
    IF @TxId IS NULL
    BEGIN
        RAISERROR('TransactionJournal not found for Inventory Adjustment %d.', 16, 1, @AdjNumber);
        RETURN;
    END;

    -- Retired-type note:
    -- Type A is no longer supported anywhere in the active UI/backend/SQL path.
    -- DeleteDetail now follows the same normal detail-delete flow for all active
    -- adjustment types. The old Type A branch is kept below as commented
    -- reference only for rollback/history review.
    /*
    IF @AdjType = 'A'
    BEGIN
        DELETE FROM dbo.InventoryAdj
        WHERE AdjId = @AdjId;

        RETURN;
    END;
    */

    -- Remove the selected detail row from both the adjustment detail table
    -- and the matching transaction journal detail rows.
    DELETE FROM dbo.InventoryAdjDetail
    WHERE AdjDetailId = @AdjDetailId;

    DELETE FROM dbo.TransactionJournalDetail
    WHERE TxId = @TxId
      AND SourceDetailId = @AdjDetailId;

    -- If that was the last detail row, remove the adjustment header too.
    SELECT @DetailCount = COUNT(*)
    FROM dbo.InventoryAdjDetail
    WHERE AdjId = @AdjId;

    IF @DetailCount = 0
    BEGIN
        DELETE FROM dbo.InventoryAdj
        WHERE AdjId = @AdjId;
    END;

    INSERT INTO dbo.RecalculationLog (ItemId, TxId, TxDate)
    VALUES (@ItemId, @TxId, @TxDate);
END
GO
