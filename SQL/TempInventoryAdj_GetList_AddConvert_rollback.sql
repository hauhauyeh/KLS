CREATE OR ALTER PROCEDURE [dbo].[TempInventoryAdj_GetList]
	@EmpId INT,
	@AdjId INT,
	@SortField NVARCHAR(50),
	@SortOrder NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Qry NVARCHAR(MAX)

	SET @Qry='SELECT t.TempAdjId,t.AdjId,t.ItemId,t.NewQty,t.NewPrice,t.Notes,i.ItemCode,i.ItemName,i.PackSize
	FROM TempInventoryAdj AS t INNER JOIN Item AS i ON t.ItemId=i.ItemId
	WHERE t.EmpId='+CONVERT(VARCHAR,@EmpId)+' AND t.AdjId='+CONVERT(VARCHAR,@AdjId)+''

	IF @SortField is not null
		SET @Qry+=' ORDER BY '+@SortField+' '+@SortOrder+''
	ELSE
		SET @Qry += ' ORDER BY t.TempAdjId'

	EXEC (@Qry)
END
