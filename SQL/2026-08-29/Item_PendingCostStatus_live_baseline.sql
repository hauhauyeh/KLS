
CREATE   PROCEDURE [dbo].[Item_PendingCostStatus]   -- EXEC dbo.Item_PendingCostStatus
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today       DATE = CAST(GETDATE() AS DATE);
    DECLARE @TodayDow    INT  = DATEPART(dw, @Today);
    DECLARE @DayOfWeek   TINYINT;
    DECLARE @RunTime     TIME;
    DECLARE @IsEnabled   BIT;
    DECLARE @Pending1    INT;
    DECLARE @Pending2    INT;
    DECLARE @AppliedToday BIT = 0;
    DECLARE @NextApply   DATE;
    DECLARE @CanApply    BIT = 0;
    DECLARE @Reason      NVARCHAR(200) = NULL;

    SELECT @DayOfWeek = DayOfWeek, @RunTime = RunTime, @IsEnabled = IsEnabled
    FROM dbo.SchedulerConfig
    WHERE JobName = 'Update Item Prices';

    SELECT @Pending1 = SUM(CASE WHEN PendingBaseCost  IS NOT NULL THEN 1 ELSE 0 END),
           @Pending2 = SUM(CASE WHEN PendingBaseCost2 IS NOT NULL THEN 1 ELSE 0 END)
    FROM dbo.ItemUnit;

    IF EXISTS (SELECT 1 FROM dbo.ItemCostApply WHERE ScheduleDate = @Today AND UndoneAt IS NULL)
        SET @AppliedToday = 1;

    IF @DayOfWeek IS NOT NULL
        SET @NextApply = DATEADD(DAY, (@DayOfWeek - @TodayDow + 7) % 7, @Today);

    IF @DayOfWeek IS NULL
        SET @Reason = 'Schedule "Update Item Prices" is not configured.';
    ELSE IF @TodayDow <> @DayOfWeek
        SET @Reason = 'Prices can only be updated on the schedule day (' + DATENAME(WEEKDAY, @NextApply) + ' ' + CONVERT(NVARCHAR(10), @NextApply, 120) + ').';
    ELSE IF @AppliedToday = 1
        SET @Reason = 'Prices already updated this week.';
    ELSE IF ISNULL(@Pending1, 0) + ISNULL(@Pending2, 0) = 0
        SET @Reason = 'Nothing pending.';
    ELSE
        SET @CanApply = 1;

    SELECT
        ISNULL(@Pending1, 0)      AS PendingUnits1,
        ISNULL(@Pending2, 0)      AS PendingUnits2,
        @DayOfWeek                AS ScheduleDayOfWeek,
        CASE WHEN @DayOfWeek IS NULL THEN NULL ELSE DATENAME(WEEKDAY, @NextApply) END AS ScheduleDayName,
        @RunTime                  AS ScheduleTime,
        @IsEnabled                AS ScheduleEnabled,
        @NextApply                AS NextApplyDate,
        @AppliedToday             AS AppliedToday,
        la.ApplyId                AS LastApplyId,
        la.AppliedAt              AS LastAppliedAt,
        la.TriggeredBy            AS LastTriggeredBy,
        la.UnitCount1             AS LastUnitCount1,
        la.UnitCount2             AS LastUnitCount2,
        @CanApply                 AS CanApply,
        @Reason                   AS CannotApplyReason
    FROM (SELECT 1 AS x) one
    OUTER APPLY
    (
        SELECT TOP (1) ApplyId, AppliedAt, TriggeredBy, UnitCount1, UnitCount2
        FROM dbo.ItemCostApply
        WHERE UndoneAt IS NULL
        ORDER BY ApplyId DESC
    ) la;
END
