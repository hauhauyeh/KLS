CREATE OR ALTER PROCEDURE [dbo].[InventoryAdj_Inject]
	@EmpId INT,
	@AdjId INT
AS
BEGIN
	SET NOCOUNT ON;

	IF @AdjId>0
	BEGIN
		DELETE FROM TempInventoryAdj WHERE EmpId=@EmpId

		INSERT INTO [dbo].[TempInventoryAdj]
           ([EmpId]
           ,[AdjId]
           ,[ItemId]
           ,[NewQty]
           ,[QtyDiffer]
           ,[NewPrice]
           ,[Notes]
           ,[AdjDetailId]
           ,[Direction])
		SELECT @EmpId
			,i.AdjId
			,id.ItemId
			,id.NewQty
			,id.QtyDiffer
			,id.NewPrice
			,id.Notes
			,id.AdjDetailId
			,id.Direction
		FROM InventoryAdj AS i INNER JOIN InventoryAdjDetail AS id ON i.AdjId=id.AdjId
		WHERE i.AdjId= @AdjId
	END
END
