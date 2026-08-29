SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-08-29 slice 4: chain Sales_RepriceOpenOrders after the cost apply. Baseline: Scheduler_UpdateItemPrice_live_baseline.sql
CREATE OR ALTER PROCEDURE [dbo].[Scheduler_UpdateItemPrice]   -- EXEC dbo.Scheduler_UpdateItemPrice
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ApplyId   INT;
    DECLARE @UnitCount INT;

    -- 2026-08-29 plan-reprice-open-orders-v1 slice 4 (D6): after the cost roll, re-price the
    -- orders flagged IsPricePending. Runs on 'Applied' AND on 'nothing pending' (51063) so
    -- Monday orders are un-flagged even when no cost changed. Not on 51062 (already applied
    -- today: the Apply Now path already repriced). Cost roll is committed before this runs;
    -- a per-order reprice error surfaces as job FAILED (51071) - Reprice Open Orders button = retry.
    DECLARE @RepriceId INT, @OrderCount INT, @LineCount INT, @SkippedCount INT, @RepriceErrors INT;

    BEGIN TRY
        EXEC dbo.Item_ApplyPendingCost
            @TriggeredBy = 'SCHEDULER',
            @EmpId       = NULL,
            @ApplyId     = @ApplyId OUTPUT,
            @UnitCount   = @UnitCount OUTPUT;

        EXEC dbo.Sales_RepriceOpenOrders @TriggeredBy = 'SCHEDULER', @EmpId = NULL, @ApplyId = @ApplyId, @SalesId = NULL,
             @RepriceId = @RepriceId OUTPUT, @OrderCount = @OrderCount OUTPUT, @LineCount = @LineCount OUTPUT, @SkippedCount = @SkippedCount OUTPUT;
        SELECT @RepriceErrors = ErrorCount FROM dbo.SalesReprice WHERE RepriceId = @RepriceId;

        SELECT @ApplyId AS ApplyId, @UnitCount AS UnitCount, 'Applied' AS Outcome,
               @RepriceId AS RepriceId, @OrderCount AS RepriceOrderCount, @LineCount AS RepriceLineCount, @SkippedCount AS RepriceSkippedCount;

        IF ISNULL(@RepriceErrors, 0) > 0
            THROW 51071, 'Cost apply succeeded but some orders failed to reprice; see SalesReprice / use Reprice Open Orders.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() IN (51062, 51063)
        BEGIN
            -- 2026-08-29: nothing pending -> still reprice/unflag Monday orders (see note above)
            IF ERROR_NUMBER() = 51063
                EXEC dbo.Sales_RepriceOpenOrders @TriggeredBy = 'SCHEDULER', @EmpId = NULL, @ApplyId = NULL, @SalesId = NULL,
                     @RepriceId = @RepriceId OUTPUT, @OrderCount = @OrderCount OUTPUT, @LineCount = @LineCount OUTPUT, @SkippedCount = @SkippedCount OUTPUT;

            SELECT NULL AS ApplyId, 0 AS UnitCount, 'Skipped: ' + ERROR_MESSAGE() AS Outcome;
            RETURN;
        END

        ;THROW;
    END CATCH
END

GO
