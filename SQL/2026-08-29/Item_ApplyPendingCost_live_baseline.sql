
CREATE   PROCEDURE [dbo].[Item_ApplyPendingCost]
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
