-- ============================================================
-- Item_ApplyPendingCost  (2026-08-27, NEW; v2 same day, write)
-- The weekly "update price" (MGP Update_PriceOnSchedule, re-homed):
--   PendingBaseCost  -> RecentBaseCost, RecentCost (= base + landed share)
--   PendingBaseCost2 -> RecentBaseCost2
-- for every unit that has a pending value, then clears the pending columns.
--
-- Two callers, same proc: the Apply Now button (@TriggeredBy = 'MANUAL')
-- and Scheduler_UpdateItemPrice (@TriggeredBy = 'SCHEDULER').
--
-- Guards (plan D10) -- every one is a THROW here; the button is only UX:
--   1. valid @TriggeredBy
--   2. schedule row 'Update Item Prices' exists
--   3. today is the schedule day (DATEPART(dw) = DayOfWeek; @@DATEFIRST = 7)
--   4. not already applied today (once per week; derived, no stored flag)
--   5. something is pending
-- Error numbers are stable so Scheduler_UpdateItemPrice can treat
-- 51062 (already applied) and 51063 (nothing pending) as a quiet skip.
--
-- Landed share (plan D3), computed on the BASE unit and scaled to each
-- unit with the ItemUnit_UpdateRecentCost formula so all units of an item
-- stay consistent:
--   share = RecentCost - RecentBaseCost when both non-NULL and > 0, else 0
--   RecentCost(unit) = PendingBaseCost(unit) + ROUND(share * Mult / Factor, 2)
--
-- v2 (2026-08-27): ItemCostApplyDetail dropped ("keep 2 tables") - the
-- new values are computed straight in the UPDATE; no per-unit old/new
-- audit and no undo. Guards, header and stamping are unchanged.
--   v1 wrote ItemCostApplyDetail first and updated from it; see
--   Item_ApplyPendingCost_live_baseline.sql.
--
-- One business event: header + unit update + import stamping in a
-- transaction with XACT_ABORT ON. No journal, no RecalculationLog, no @INV.
-- Does NOT reprice open sales orders (plan D12, out of scope).
-- ============================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Item_ApplyPendingCost]
    -- DECLARE @id INT, @n INT;
    -- EXEC dbo.Item_ApplyPendingCost @TriggeredBy = 'MANUAL', @EmpId = 1, @ApplyId = @id OUTPUT, @UnitCount = @n OUTPUT;

    @TriggeredBy NVARCHAR(20),
    @EmpId       INT = NULL,
    @ApplyId     INT OUTPUT,
    @UnitCount   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ApplyId = NULL;
    SET @UnitCount = 0;

    DECLARE @Today     DATE = CAST(GETDATE() AS DATE);
    DECLARE @TodayDow  INT  = DATEPART(dw, @Today);
    DECLARE @DayOfWeek TINYINT;
    DECLARE @NextApply DATE;
    DECLARE @Msg       NVARCHAR(400);
    DECLARE @Count1    INT;
    DECLARE @Count2    INT;

    -- Guard 1
    IF @TriggeredBy NOT IN ('MANUAL', 'SCHEDULER')
        THROW 51060, 'TriggeredBy must be MANUAL or SCHEDULER.', 1;

    -- Guard 2
    SELECT @DayOfWeek = DayOfWeek
    FROM dbo.SchedulerConfig
    WHERE JobName = 'Update Item Prices';

    IF @DayOfWeek IS NULL
        THROW 51061, 'Schedule "Update Item Prices" is not configured.', 1;

    -- Guard 3
    IF @TodayDow <> @DayOfWeek
    BEGIN
        SET @NextApply = DATEADD(DAY, (@DayOfWeek - @TodayDow + 7) % 7, @Today);
        SET @Msg = 'Prices can only be updated on the schedule day (' + DATENAME(WEEKDAY, @NextApply) + ' ' + CONVERT(NVARCHAR(10), @NextApply, 120) + ').';
        THROW 51064, @Msg, 1;
    END

    -- Guard 4
    IF EXISTS (SELECT 1 FROM dbo.ItemCostApply WHERE ScheduleDate = @Today AND UndoneAt IS NULL)
        THROW 51062, 'Prices already updated this week.', 1;

    -- Guard 5
    IF NOT EXISTS (SELECT 1 FROM dbo.ItemUnit WHERE PendingBaseCost IS NOT NULL OR PendingBaseCost2 IS NOT NULL)
        THROW 51063, 'Nothing pending.', 1;

    BEGIN TRAN;

        SELECT @Count1 = SUM(CASE WHEN PendingBaseCost  IS NOT NULL THEN 1 ELSE 0 END),
               @Count2 = SUM(CASE WHEN PendingBaseCost2 IS NOT NULL THEN 1 ELSE 0 END)
        FROM dbo.ItemUnit;

        INSERT INTO dbo.ItemCostApply (TriggeredBy, EmpId, ScheduleDate, UnitCount1, UnitCount2)
        VALUES (@TriggeredBy, @EmpId, @Today, ISNULL(@Count1, 0), ISNULL(@Count2, 0));

        SET @ApplyId = SCOPE_IDENTITY();

        -- Base-unit landed share per item (Tier 1 only).
        SELECT
            bu.ItemId,
            CASE
                WHEN bu.RecentCost IS NOT NULL AND bu.RecentBaseCost IS NOT NULL
                     AND bu.RecentCost - bu.RecentBaseCost > 0
                THEN bu.RecentCost - bu.RecentBaseCost
                ELSE 0
            END AS LandedShare
        INTO #Share
        FROM dbo.ItemUnit bu
        WHERE bu.IsBaseUnit = 1
          AND EXISTS (SELECT 1 FROM dbo.ItemUnit x WHERE x.ItemId = bu.ItemId AND x.PendingBaseCost IS NOT NULL);

        -- Go live. Tier 1 keeps the landed share; Tier 2 is the reference cost only.
        UPDATE u
        SET u.RecentBaseCost   = ISNULL(u.PendingBaseCost, u.RecentBaseCost),
            u.RecentCost       = CASE
                                     WHEN u.PendingBaseCost IS NULL THEN u.RecentCost
                                     ELSE u.PendingBaseCost
                                        + ROUND(ISNULL(s.LandedShare, 0) * ISNULL(NULLIF(u.MultipleToBase, 0), 1) / NULLIF(u.FactorToBase, 0), 2)
                                 END,
            u.RecentBaseCost2  = ISNULL(u.PendingBaseCost2, u.RecentBaseCost2),
            u.PendingBaseCost  = NULL,
            u.PendingBaseCost2 = NULL
        FROM dbo.ItemUnit u
        LEFT JOIN #Share s ON s.ItemId = u.ItemId
        WHERE u.PendingBaseCost IS NOT NULL
           OR u.PendingBaseCost2 IS NOT NULL;

        SET @UnitCount = @@ROWCOUNT;

        IF @UnitCount = 0
            THROW 51065, 'Apply changed 0 units. Nothing was changed.', 1;

        -- Every import that was waiting is now consumed by this apply.
        UPDATE dbo.ItemCostImport
        SET ApplyId = @ApplyId
        WHERE ApplyId IS NULL
          AND UndoneAt IS NULL;

        DROP TABLE #Share;

    COMMIT;
END
GO
