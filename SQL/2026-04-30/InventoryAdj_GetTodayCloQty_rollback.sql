SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[InventoryAdj_GetTodayCloQty]

	@ItemId INT
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @Today DATE = GETDATE();
	DECLARE @InventoryAccountId INT;
	DECLARE @TodayClosingQty DECIMAL(18,6);
	DECLARE @TodayAverageCost DECIMAL(18,6);
	DECLARE @StoredClosingQty DECIMAL(18,6);
	DECLARE @StoredAverageCost DECIMAL(18,6);

	SELECT @InventoryAccountId = AccountId
	FROM dbo.Account
	WHERE AccountCode = '@INV';

	SELECT TOP (1)
		@TodayClosingQty = td.ClosingQty,
		@TodayAverageCost = td.AverageCost
	FROM dbo.TransactionJournal AS t
	INNER JOIN dbo.TransactionJournalDetail AS td ON t.TxId = td.TxId
	WHERE td.AccountId = @InventoryAccountId
	  AND td.ItemId = @ItemId
	  AND t.TxDate = @Today
	ORDER BY t.SourceDocOrder DESC, td.TxDetailId DESC;

	IF @TodayClosingQty IS NOT NULL
	BEGIN
		SELECT
			@ItemId AS ItemId,
			@TodayClosingQty AS ClosingQty,
			@TodayAverageCost AS AverageCost;

		RETURN;
	END;

	SELECT
		@StoredClosingQty = i.LCloseQty,
		@StoredAverageCost = i.LAvgCost
	FROM dbo.Item AS i
	WHERE i.ItemId = @ItemId;

	SELECT
		@ItemId AS ItemId,
		ISNULL(@StoredClosingQty, 0) AS ClosingQty,
		ISNULL(@StoredAverageCost, 0) AS AverageCost;
END
GO
