CREATE PROCEDURE [dbo].[ItemHistory_Sales] --[ItemHistory_Sales] 0,0,null
	
	@ItemId INT,
	@PayeeId INT,
	@Filterby NVARCHAR(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX)

	SET @Qry='SELECT TOP 300 
	sd.SalesDetailId
	,s.SalesNumber
	,s.SalesId
	,s.ShipDate
	,s.ShipId
	,p.PayeeName
	,sd.ShipQty
	,sd.Unit
	,sd.UnitPrice
	FROM Sales AS s INNER JOIN SalesDetail AS sd on s.SalesId=sd.SalesId
	Inner JOIN Payee as p ON p.PayeeId=s.ShipId
	WHERE (sd.ItemId='+convert(varchar,@ItemId)+') AND (s.ShipId='+convert(varchar,@PayeeId)+' OR '+convert(varchar,@PayeeId)+'=0) '

	IF @Filterby='future'
		SET @Qry+=' AND s.ShipDate>convert(date,GETDATE())'
	ELSE IF @Filterby='today'
		SET @Qry+=' AND s.ShipDate=convert(date,GETDATE())'

	SET @Qry+=' ORDER BY s.ShipDate DESC,p.PayeeName'

	EXEC (@Qry)
END
