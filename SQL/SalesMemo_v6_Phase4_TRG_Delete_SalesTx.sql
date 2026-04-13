SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER TRIGGER [dbo].[TRG_Delete_SalesTx]
   ON  dbo.Sales 
   INSTEAD OF DELETE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @SalesId INT; 
	DECLARE @SalesNumber INT; 
	DECLARE @PayeeId INT
	DECLARE @DocType CHAR(2)
	DECLARE @JournalDocType NVARCHAR(100)
	DECLARE @RowNum INT=1  -- DECLARING VARIABLE FOR COUNTING CURRENT ROW.
	DECLARE @MaxRow INT -- DECLARING MAXIMUM ROW NUMBER

	CREATE TABLE #SalesDelete (	-- CREATING TABLE CONTAINNG TWO COLUMN.
		AutoId INT IDENTITY(1,1) PRIMARY KEY,  -- UNIQUE ID FOR RACH ROW.
		SalesId INT,
		SalesNumber INT,
		PayeeId INT,
		DocType CHAR(2)
	)

	INSERT INTO #SalesDelete(SalesId,SalesNumber,PayeeId,DocType) 
	SELECT SalesId,SalesNumber,ShipId,ISNULL(DocType,'SO') FROM DELETED  

	SELECT @MaxRow=COUNT(AutoId) FROM #SalesDelete

	WHILE @RowNum<=@MaxRow
	BEGIN
		SELECT @SalesId=SalesId,@SalesNumber=SalesNumber,@PayeeId=PayeeId,@DocType=DocType
		FROM #SalesDelete WHERE AutoId=@RowNum

		SET @JournalDocType = CASE @DocType
			WHEN 'CM' THEN 'Sales Credit Memo'
			WHEN 'DM' THEN 'Sales Debit Memo'
			ELSE 'Sales'
		END

		DELETE FROM Sales WHERE SalesId=@SalesId

		DELETE TransactionJournal WHERE SourceDocType=@JournalDocType AND SourceDocNumber=@SalesNumber

		EXEC [Payee_UpdateAging] @PayeeId,1	

		SET @RowNum += 1
	END
END
GO
