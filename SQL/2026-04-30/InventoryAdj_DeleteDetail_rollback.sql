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

    SELECT
        @AdjId = iad.AdjId,
        @ItemId = iad.ItemId
    FROM dbo.InventoryAdjDetail AS iad
    WHERE iad.AdjDetailId = @AdjDetailId;

    SELECT
        @AdjNumber = ia.AdjNumber,
        @AdjType = ia.AdjType
    FROM dbo.InventoryAdj AS ia
    WHERE ia.AdjId = @AdjId;

    SELECT
        @TxId = tj.TxId,
        @TxDate = tj.TxDate
    FROM dbo.TransactionJournal AS tj
    WHERE tj.SourceDocNumber = @AdjNumber
      AND tj.SourceDocType = 'Inventory Adj';

    IF @TxId IS NULL
    BEGIN
        RAISERROR('TransactionJournal not found for Inventory Adjustment %d.', 16, 1, @AdjNumber);
        RETURN;
    END;

    IF @AdjType = 'A'
    BEGIN
        DELETE FROM dbo.InventoryAdj
        WHERE AdjId = @AdjId;

        RETURN;
    END;

    DELETE FROM dbo.InventoryAdjDetail
    WHERE AdjDetailId = @AdjDetailId;

    DELETE FROM dbo.TransactionJournalDetail
    WHERE TxId = @TxId
      AND SourceDetailId = @AdjDetailId;

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
