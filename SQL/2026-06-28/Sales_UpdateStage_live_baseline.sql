CREATE   PROCEDURE [dbo].[Sales_UpdateStage]
    @SalesId INT,
    @StageId INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentStageId INT;
    SELECT @CurrentStageId = StageId
    FROM dbo.Sales
    WHERE SalesId = @SalesId;
    UPDATE dbo.Sales
    SET StageId = @StageId,
        UpdatedAt = GETUTCDATE()
    WHERE SalesId = @SalesId;
    IF @CurrentStageId = 2
       AND @StageId = 0
    BEGIN
        UPDATE sd
        SET sd.FIFOHistory = NULL,
            sd.FIFOCost = NULL
        FROM dbo.SalesDetail sd
        WHERE sd.SalesId = @SalesId
          AND (sd.FIFOHistory IS NOT NULL OR sd.FIFOCost IS NOT NULL);
    END
    IF @CurrentStageId = 0
       AND @StageId <> 0
    BEGIN
        EXEC dbo.FIFO_Single_Allocation @SalesId;
    END
    SELECT *
    FROM dbo.SalesStage
    WHERE StageId = @StageId;
END
