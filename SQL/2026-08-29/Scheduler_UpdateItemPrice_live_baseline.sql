
CREATE   PROCEDURE [dbo].[Scheduler_UpdateItemPrice]   -- EXEC dbo.Scheduler_UpdateItemPrice
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ApplyId   INT;
    DECLARE @UnitCount INT;

    BEGIN TRY
        EXEC dbo.Item_ApplyPendingCost
            @TriggeredBy = 'SCHEDULER',
            @EmpId       = NULL,
            @ApplyId     = @ApplyId OUTPUT,
            @UnitCount   = @UnitCount OUTPUT;

        SELECT @ApplyId AS ApplyId, @UnitCount AS UnitCount, 'Applied' AS Outcome;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (51062, 51063)
        BEGIN
            SELECT NULL AS ApplyId, 0 AS UnitCount, 'Skipped: ' + ERROR_MESSAGE() AS Outcome;
            RETURN;
        END

        ;THROW;
    END CATCH
END
