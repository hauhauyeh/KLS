SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-06-28: FIFO caller cutover -- repointed the final-stage allocation from
-- FIFO_Single_Allocation to the unified FIFO_Single_Allocation_Unified @Stage='final'.
-- Old EXEC kept commented (per workflow). Behavior identical; the old SP is retained.
DROP PROCEDURE IF EXISTS [dbo].[Sales_UpdateStage]
GO
CREATE PROCEDURE [dbo].[Sales_UpdateStage] -- EXEC Sales_UpdateStage @SalesId=70693,@StageId=2
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
        -- 2026-06-28: cutover to unified allocator (final stage)
        -- EXEC dbo.FIFO_Single_Allocation @SalesId;
        EXEC dbo.FIFO_Single_Allocation_Unified @SalesId, @Stage = 'final';
    END
    SELECT *
    FROM dbo.SalesStage
    WHERE StageId = @StageId;
END
GO
