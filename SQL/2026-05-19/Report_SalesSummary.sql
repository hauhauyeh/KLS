-- Report_SalesSummary — 2026-05-19 hard floor at 2024-01-01 + quarter grain.
-- Any Sales row with SalesDate before 2024-01-01 is excluded from both
-- Cur and Prior aggregations, so pre-2024 periods naturally come out as 0
-- via the existing ISNULL(..., 0) projection.
-- Quarter grain added alongside day/week/month/year.

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Report_SalesSummary')
   AND NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'Report_SalesSummary_prev')
    EXEC sp_rename 'Report_SalesSummary', 'Report_SalesSummary_prev';
GO

IF OBJECT_ID('dbo.Report_SalesSummary', 'P') IS NOT NULL
    DROP PROCEDURE dbo.Report_SalesSummary;
GO

CREATE PROCEDURE [dbo].[Report_SalesSummary]
    @Grain      NVARCHAR(10) = 'month',
    @StartDate  DATE         = NULL,
    @EndDate    DATE         = NULL,
    @SalesRepId INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Phase 1. Validate @Grain. Reject anything outside the allowed set
    -- so the SP can't be coerced into running silent-no-op SQL by a typo.
    IF @Grain NOT IN ('day', 'week', 'month', 'quarter', 'year')
        THROW 50020, 'Invalid @Grain. Use ''day'', ''week'', ''month'', ''quarter'', or ''year''.', 1;

    -- Hard floor: business agreement to ignore pre-2024 data.
    DECLARE @DataFloor DATE = '2024-01-01';

    -- Phase 2. Default the date range per grain when caller passes NULL.
    DECLARE @Today DATE = CAST(GETDATE() AS DATE);
    IF @EndDate IS NULL SET @EndDate = @Today;
    IF @StartDate IS NULL
    BEGIN
        SET @StartDate =
            CASE @Grain
                WHEN 'day'     THEN DATEADD(DAY,     -29, @EndDate)
                WHEN 'week'    THEN DATEADD(WEEK,    -12, @EndDate)
                WHEN 'month'   THEN DATEADD(MONTH,   -11, @EndDate)
                WHEN 'quarter' THEN DATEADD(QUARTER,  -7, @EndDate)
                WHEN 'year'    THEN DATEADD(YEAR,     -4, @EndDate)
            END;

        -- For long grains, anchor at the floor when the computed default
        -- would hide buckets that still have data (e.g., quarter -7 from
        -- mid-2026 lands in Q3 2024, hiding Q1 and Q2 2024).
        IF @Grain IN ('quarter', 'year') AND @StartDate > @DataFloor
            SET @StartDate = @DataFloor;
    END

    -- Phase 3. Build the calendar dimension (#Periods) for this run.
    -- Each row is one expected period in the [@StartDate, @EndDate] range
    -- with display fields + the grain-aware PeriodKey / PriorPeriodKey
    -- used for the Cur / Prior aggregations below.
    CREATE TABLE #Periods
    (
        PeriodStart    DATE          NOT NULL,
        PeriodEnd      DATE          NOT NULL,
        PeriodLabel    NVARCHAR(50)  NOT NULL,
        PeriodKey      BIGINT        NOT NULL,
        PriorPeriodKey BIGINT        NOT NULL,
        PRIMARY KEY (PeriodStart)
    );

    IF @Grain = 'day'
    BEGIN
        ;WITH D AS
        (
            SELECT @StartDate AS d
            UNION ALL
            SELECT DATEADD(DAY, 1, d) FROM D WHERE d < @EndDate
        )
        INSERT INTO #Periods (PeriodStart, PeriodEnd, PeriodLabel, PeriodKey, PriorPeriodKey)
        SELECT
            d,
            d,
            CONVERT(NVARCHAR(10), d, 23),   -- 'YYYY-MM-DD'
            CAST(YEAR(d) AS BIGINT) * 10000 + MONTH(d) * 100 + DAY(d),
            CAST(YEAR(DATEADD(YEAR, -1, d)) AS BIGINT) * 10000
                + MONTH(DATEADD(YEAR, -1, d)) * 100
                + DAY(DATEADD(YEAR, -1, d))
        FROM D
        OPTION (MAXRECURSION 400);
    END
    ELSE IF @Grain = 'week'
    BEGIN
        -- Snap @StartDate back to the Monday on or before it.
        -- Formula is DATEFIRST-agnostic: (DATEPART(WEEKDAY,d) + @@DATEFIRST - 2) % 7
        -- gives 0 for Monday, 1 for Tuesday, ..., 6 for Sunday.
        DECLARE @MondayStart DATE =
            DATEADD(DAY, -((DATEPART(WEEKDAY, @StartDate) + @@DATEFIRST - 2) % 7), @StartDate);

        ;WITH W AS
        (
            SELECT @MondayStart AS d
            UNION ALL
            SELECT DATEADD(WEEK, 1, d) FROM W WHERE d < @EndDate
        )
        INSERT INTO #Periods (PeriodStart, PeriodEnd, PeriodLabel, PeriodKey, PriorPeriodKey)
        SELECT
            d,
            DATEADD(DAY, 6, d),                                     -- Mon..Sun
            CONCAT('Wk ', DATEPART(ISO_WEEK, d), ' (', FORMAT(d, 'MMM dd'), ')'),
            -- IsoYear * 100 + IsoWeek. Late-Dec dates in ISO week 52/53 of
            -- the next year, and early-Jan dates in ISO week 1 of the prior
            -- year, get nudged to the correct IsoYear.
            (CAST(
                CASE
                    WHEN DATEPART(ISO_WEEK, d) >= 52 AND MONTH(d) = 1  THEN YEAR(d) - 1
                    WHEN DATEPART(ISO_WEEK, d) = 1   AND MONTH(d) = 12 THEN YEAR(d) + 1
                    ELSE YEAR(d)
                END AS BIGINT) * 100) + DATEPART(ISO_WEEK, d),
            ((CAST(
                CASE
                    WHEN DATEPART(ISO_WEEK, d) >= 52 AND MONTH(d) = 1  THEN YEAR(d) - 1
                    WHEN DATEPART(ISO_WEEK, d) = 1   AND MONTH(d) = 12 THEN YEAR(d) + 1
                    ELSE YEAR(d)
                END AS BIGINT) - 1) * 100) + DATEPART(ISO_WEEK, d)
        FROM W
        OPTION (MAXRECURSION 300);
    END
    ELSE IF @Grain = 'month'
    BEGIN
        DECLARE @MonthStart DATE = DATEFROMPARTS(YEAR(@StartDate), MONTH(@StartDate), 1);

        ;WITH M AS
        (
            SELECT @MonthStart AS d
            UNION ALL
            SELECT DATEADD(MONTH, 1, d) FROM M WHERE d < @EndDate
        )
        INSERT INTO #Periods (PeriodStart, PeriodEnd, PeriodLabel, PeriodKey, PriorPeriodKey)
        SELECT
            d,
            EOMONTH(d),
            FORMAT(d, 'yyyy-MM'),
            CAST(YEAR(d) AS BIGINT) * 100 + MONTH(d),
            CAST(YEAR(d) - 1 AS BIGINT) * 100 + MONTH(d)
        FROM M
        OPTION (MAXRECURSION 200);
    END
    ELSE IF @Grain = 'quarter'
    BEGIN
        -- Snap @StartDate to the first day of its quarter.
        DECLARE @QuarterStart DATE =
            DATEFROMPARTS(YEAR(@StartDate), ((DATEPART(QUARTER, @StartDate) - 1) * 3) + 1, 1);

        ;WITH Q AS
        (
            SELECT @QuarterStart AS d
            UNION ALL
            SELECT DATEADD(QUARTER, 1, d) FROM Q WHERE d < @EndDate
        )
        INSERT INTO #Periods (PeriodStart, PeriodEnd, PeriodLabel, PeriodKey, PriorPeriodKey)
        SELECT
            d,
            EOMONTH(DATEADD(MONTH, 2, d)),
            CONCAT(YEAR(d), '-Q', DATEPART(QUARTER, d)),
            CAST(YEAR(d) AS BIGINT) * 10 + DATEPART(QUARTER, d),
            CAST(YEAR(d) - 1 AS BIGINT) * 10 + DATEPART(QUARTER, d)
        FROM Q
        OPTION (MAXRECURSION 100);
    END
    ELSE IF @Grain = 'year'
    BEGIN
        DECLARE @YearStart DATE = DATEFROMPARTS(YEAR(@StartDate), 1, 1);

        ;WITH Y AS
        (
            SELECT @YearStart AS d
            UNION ALL
            SELECT DATEADD(YEAR, 1, d) FROM Y WHERE d < @EndDate
        )
        INSERT INTO #Periods (PeriodStart, PeriodEnd, PeriodLabel, PeriodKey, PriorPeriodKey)
        SELECT
            d,
            DATEFROMPARTS(YEAR(d), 12, 31),
            CAST(YEAR(d) AS NVARCHAR(4)),
            CAST(YEAR(d) AS BIGINT),
            CAST(YEAR(d) - 1 AS BIGINT)
        FROM Y
        OPTION (MAXRECURSION 100);
    END;

    -- Clip periods to the data window. The recursive CTE can overshoot
    -- @EndDate by one step; @DataFloor hides anything entirely pre-2024.
    -- Keep any period whose range overlaps [@DataFloor, @EndDate].
    DELETE FROM #Periods
    WHERE PeriodEnd   < @DataFloor
       OR PeriodStart > @EndDate;

    -- Phase 4. Aggregate Sales for the current and prior windows.
    -- Both CTEs use the SAME PeriodKey expression (via CROSS APPLY) so
    -- 'this week of 2026' and 'this week of 2025' produce the SAME key
    -- after the prior window's date-shift.
    ;WITH Cur AS
    (
        SELECT
            x.PeriodKey,
            TotalAmount = SUM(s.SalesTotal),
            TxCount     = COUNT(s.SalesId)
        FROM dbo.Sales s
        CROSS APPLY (
            SELECT PeriodKey =
                CASE @Grain
                    WHEN 'day'   THEN CAST(YEAR(s.SalesDate) AS BIGINT) * 10000 + MONTH(s.SalesDate) * 100 + DAY(s.SalesDate)
                    WHEN 'week'  THEN
                        (CAST(
                            CASE
                                WHEN DATEPART(ISO_WEEK, s.SalesDate) >= 52 AND MONTH(s.SalesDate) = 1  THEN YEAR(s.SalesDate) - 1
                                WHEN DATEPART(ISO_WEEK, s.SalesDate) = 1   AND MONTH(s.SalesDate) = 12 THEN YEAR(s.SalesDate) + 1
                                ELSE YEAR(s.SalesDate)
                            END AS BIGINT) * 100) + DATEPART(ISO_WEEK, s.SalesDate)
                    WHEN 'month'   THEN CAST(YEAR(s.SalesDate) AS BIGINT) * 100 + MONTH(s.SalesDate)
                    WHEN 'quarter' THEN CAST(YEAR(s.SalesDate) AS BIGINT) * 10  + DATEPART(QUARTER, s.SalesDate)
                    WHEN 'year'    THEN CAST(YEAR(s.SalesDate) AS BIGINT)
                END
        ) x
        WHERE s.SalesDate >= @StartDate
          AND s.SalesDate <  DATEADD(DAY, 1, @EndDate)
          AND s.SalesDate >= @DataFloor
          AND (@SalesRepId IS NULL OR s.SalesRepId = @SalesRepId)
        GROUP BY x.PeriodKey
    ),
    Prior AS
    (
        SELECT
            x.PeriodKey,
            TotalAmount = SUM(s.SalesTotal),
            TxCount     = COUNT(s.SalesId)
        FROM dbo.Sales s
        CROSS APPLY (
            SELECT PeriodKey =
                CASE @Grain
                    WHEN 'day'   THEN CAST(YEAR(s.SalesDate) AS BIGINT) * 10000 + MONTH(s.SalesDate) * 100 + DAY(s.SalesDate)
                    WHEN 'week'  THEN
                        (CAST(
                            CASE
                                WHEN DATEPART(ISO_WEEK, s.SalesDate) >= 52 AND MONTH(s.SalesDate) = 1  THEN YEAR(s.SalesDate) - 1
                                WHEN DATEPART(ISO_WEEK, s.SalesDate) = 1   AND MONTH(s.SalesDate) = 12 THEN YEAR(s.SalesDate) + 1
                                ELSE YEAR(s.SalesDate)
                            END AS BIGINT) * 100) + DATEPART(ISO_WEEK, s.SalesDate)
                    WHEN 'month'   THEN CAST(YEAR(s.SalesDate) AS BIGINT) * 100 + MONTH(s.SalesDate)
                    WHEN 'quarter' THEN CAST(YEAR(s.SalesDate) AS BIGINT) * 10  + DATEPART(QUARTER, s.SalesDate)
                    WHEN 'year'    THEN CAST(YEAR(s.SalesDate) AS BIGINT)
                END
        ) x
        WHERE s.SalesDate >= DATEADD(YEAR, -1, @StartDate)
          AND s.SalesDate <  DATEADD(YEAR, -1, DATEADD(DAY, 1, @EndDate))
          AND s.SalesDate >= @DataFloor
          AND (@SalesRepId IS NULL OR s.SalesRepId = @SalesRepId)
        GROUP BY x.PeriodKey
    )
    SELECT
        pr.PeriodStart,
        pr.PeriodEnd,
        pr.PeriodLabel,
        @Grain                                              AS Grain,
        ISNULL(c.TotalAmount, 0)                            AS CurrentTotal,
        ISNULL(p.TotalAmount, 0)                            AS PriorTotal,
        ISNULL(c.TotalAmount, 0) - ISNULL(p.TotalAmount, 0) AS DeltaAmount,
        CASE WHEN ISNULL(p.TotalAmount, 0) = 0 THEN NULL
             ELSE (ISNULL(c.TotalAmount, 0) - p.TotalAmount) * 100.0 / p.TotalAmount
        END                                                 AS DeltaPercent,
        ISNULL(c.TxCount, 0)                                AS CurrentTx,
        ISNULL(p.TxCount, 0)                                AS PriorTx
    FROM #Periods pr
    LEFT JOIN Cur   c ON c.PeriodKey = pr.PeriodKey
    LEFT JOIN Prior p ON p.PeriodKey = pr.PriorPeriodKey
    ORDER BY pr.PeriodStart;

    DROP TABLE #Periods;
END;
GO
