
CREATE PROCEDURE [dbo].[_postmigration_RunRecalcQAV_ForItemCache]
    @RunMode NVARCHAR(30) = 'INVENTORY_HISTORY_ONLY',
    @RecalcBeginDate DATE = '2024-01-01',
    @MarkProcessedRecalcLogDeleted BIT = 0,
    @ManualItemIds NVARCHAR(MAX) = '410'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
    Purpose:
        Run dbo.RecalcQAV and refresh the cached item inventory fields in dbo.Item.

    Cached item fields refreshed by this procedure:
        - Item.LCloseQty
        - Item.LAvgCost
        - Item.LInventoryValue

    Run modes:
        1. INVENTORY_HISTORY_ONLY
           Recalculate only items that actually exist on inventory journal rows
           in dbo.TransactionJournalDetail for AccountCode = '@INV'.
           This is the recommended broad postmigration mode because it skips item
           rows that have no inventory journal history to rebuild.

        2. RECALC_LOG
           Recalculate only items currently queued in dbo.RecalculationLog where IsDeleted = 0.
           This is the normal narrower maintenance mode.

        3. MANUAL_TARGET_ITEMS
           Recalculate only the ItemId values passed through @ManualItemIds.

    Execution examples:
        1. Recalculate all items that exist on inventory journal rows from 2024-01-01:
           EXEC dbo._postmigration_RunRecalcQAV_ForItemCache;

        2. Recalculate only items currently queued in RecalculationLog, but still start from 2024-01-01:
           EXEC dbo._postmigration_RunRecalcQAV_ForItemCache
               @RunMode = 'RECALC_LOG',
               @RecalcBeginDate = '2024-01-01';

        3. Recalculate only a few manual item ids from 2024-01-01:
           EXEC dbo._postmigration_RunRecalcQAV_ForItemCache
               @RunMode = 'MANUAL_TARGET_ITEMS',
               @RecalcBeginDate = '2024-01-01',
               @ManualItemIds = '1,2,3';
    */

    -- Section 1. Build the optional manual item target list from the csv parameter.
    IF OBJECT_ID('tempdb..#ManualTargetItems') IS NOT NULL
        DROP TABLE #ManualTargetItems;

    CREATE TABLE #ManualTargetItems
    (
        ItemId INT NOT NULL PRIMARY KEY
    );

    IF @ManualItemIds IS NOT NULL AND LTRIM(RTRIM(@ManualItemIds)) <> ''
    BEGIN
        INSERT INTO #ManualTargetItems (ItemId)
        SELECT DISTINCT TRY_CONVERT(INT, LTRIM(RTRIM(value)))
        FROM STRING_SPLIT(@ManualItemIds, ',')
        WHERE TRY_CONVERT(INT, LTRIM(RTRIM(value))) IS NOT NULL;
    END;

    -- Section 2. Validate the requested mode before any work begins.
    IF @RunMode NOT IN ('INVENTORY_HISTORY_ONLY', 'RECALC_LOG', 'MANUAL_TARGET_ITEMS')
    BEGIN
        THROW 50101, 'Invalid @RunMode. Allowed values are INVENTORY_HISTORY_ONLY, RECALC_LOG, and MANUAL_TARGET_ITEMS.', 1;
    END;

    IF @RunMode = 'MANUAL_TARGET_ITEMS'
       AND NOT EXISTS (SELECT 1 FROM #ManualTargetItems)
    BEGIN
        THROW 50102, 'MANUAL_TARGET_ITEMS mode requires at least one integer ItemId in @ManualItemIds.', 1;
    END;

    -- Section 3. Build the item target scope and the begin date used for each RecalcQAV call.
    IF OBJECT_ID('tempdb..#TargetItems') IS NOT NULL
        DROP TABLE #TargetItems;

    CREATE TABLE #TargetItems
    (
        RowNum INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ItemId INT NOT NULL,
        BeginDate DATE NOT NULL,
        SourceMode NVARCHAR(30) NOT NULL
    );

    IF @RunMode = 'INVENTORY_HISTORY_ONLY'
    BEGIN
        DECLARE @InventoryAccountId INT;

        SELECT @InventoryAccountId = a.AccountId
        FROM dbo.Account AS a
        WHERE a.AccountCode = '@INV';

        IF @InventoryAccountId IS NULL
        BEGIN
            THROW 50103, 'Inventory account @INV was not found. Cannot build INVENTORY_HISTORY_ONLY scope.', 1;
        END;

        INSERT INTO #TargetItems
        (
            ItemId,
            BeginDate,
            SourceMode
        )
        SELECT
            td.ItemId,
            @RecalcBeginDate,
            'INVENTORY_HISTORY_ONLY'
        FROM dbo.TransactionJournalDetail AS td
        WHERE td.AccountId = @InventoryAccountId
          AND td.ItemId IS NOT NULL
        GROUP BY td.ItemId
        ORDER BY td.ItemId;
    END;
    ELSE IF @RunMode = 'RECALC_LOG'
    BEGIN
        INSERT INTO #TargetItems
        (
            ItemId,
            BeginDate,
            SourceMode
        )
        SELECT
            rl.ItemId,
            @RecalcBeginDate,
            'RECALC_LOG'
        FROM dbo.RecalculationLog AS rl
        WHERE ISNULL(rl.IsDeleted, 0) = 0
          AND rl.ItemId IS NOT NULL
        GROUP BY rl.ItemId
        ORDER BY rl.ItemId;
    END;
    ELSE IF @RunMode = 'MANUAL_TARGET_ITEMS'
    BEGIN
        INSERT INTO #TargetItems
        (
            ItemId,
            BeginDate,
            SourceMode
        )
        SELECT
            mti.ItemId,
            @RecalcBeginDate,
            'MANUAL_TARGET_ITEMS'
        FROM #ManualTargetItems AS mti
        ORDER BY mti.ItemId;
    END;

    SELECT COUNT(*) AS TargetItemCount, @RunMode AS RunMode, @RecalcBeginDate AS RecalcBeginDate
    FROM #TargetItems;

    IF NOT EXISTS (SELECT 1 FROM #TargetItems)
    BEGIN
        PRINT 'No target items were found for this run mode.';
        RETURN;
    END;

    SELECT TOP (200)
        ti.ItemId,
        ti.BeginDate,
        ti.SourceMode
    FROM #TargetItems AS ti
    ORDER BY ti.RowNum;

    -- Section 4. Prepare the result capture table for the recalculation run.
    IF OBJECT_ID('tempdb..#RecalcResult') IS NOT NULL
        DROP TABLE #RecalcResult;

    CREATE TABLE #RecalcResult
    (
        ItemId INT NOT NULL PRIMARY KEY,
        BeginDate DATE NOT NULL,
        LCloseQty DECIMAL(18, 6) NULL,
        LAvgCost DECIMAL(18, 6) NULL,
        LInventoryValue DECIMAL(18, 6) NULL
    );

    -- Section 5. Run RecalcQAV row by row and capture the final values for dbo.Item.
    DECLARE
        @RowNum INT = 1,
        @MaxRow INT,
        @ItemId INT,
        @BeginDate DATE,
        @ProgressInterval INT = 25,
        @StartMessage NVARCHAR(4000),
        @ProgressMessage NVARCHAR(4000),
        @FinishMessage NVARCHAR(4000),
        @LCloseQty DECIMAL(18, 6),
        @LAvgCost DECIMAL(18, 6),
        @LInventoryValue DECIMAL(18, 6);

    SELECT @MaxRow = COUNT(*)
    FROM #TargetItems;

    SET @StartMessage =
        'RecalcQAV run started. RunMode = ' + ISNULL(@RunMode, '') +
        '. BeginDate = ' + CONVERT(VARCHAR(10), @RecalcBeginDate, 120) +
        '. TargetItemCount = ' + CONVERT(VARCHAR(20), @MaxRow) + '.';

    RAISERROR('%s', 0, 1, @StartMessage) WITH NOWAIT;

    WHILE @RowNum <= @MaxRow
    BEGIN
        SELECT
            @ItemId = ti.ItemId,
            @BeginDate = ti.BeginDate
        FROM #TargetItems AS ti
        WHERE ti.RowNum = @RowNum;

        SET @LCloseQty = 0;
        SET @LAvgCost = 0;
        SET @LInventoryValue = 0;

        EXEC dbo.RecalcQAV
            @ItemId = @ItemId,
            @BeginDate = @BeginDate,
            @LCloQty = @LCloseQty OUTPUT,
            @LAvgCost = @LAvgCost OUTPUT,
            @LInventoryValue = @LInventoryValue OUTPUT;

        INSERT INTO #RecalcResult
        (
            ItemId,
            BeginDate,
            LCloseQty,
            LAvgCost,
            LInventoryValue
        )
        VALUES
        (
            @ItemId,
            @BeginDate,
            @LCloseQty,
            @LAvgCost,
            @LInventoryValue
        );

        IF @RowNum = 1 OR @RowNum % @ProgressInterval = 0 OR @RowNum = @MaxRow
        BEGIN
            SET @ProgressMessage =
                'RecalcQAV progress: ' + CONVERT(VARCHAR(20), @RowNum) +
                ' of ' + CONVERT(VARCHAR(20), @MaxRow) +
                ' items complete. Current ItemId = ' + CONVERT(VARCHAR(20), @ItemId) + '.';

            RAISERROR('%s', 0, 1, @ProgressMessage) WITH NOWAIT;
        END;

        SET @RowNum += 1;
    END;

    -- Section 6. Write the final recalculated values back into dbo.Item.
    UPDATE i
    SET
        i.LCloseQty = rr.LCloseQty,
        i.LAvgCost = rr.LAvgCost,
        i.LInventoryValue = rr.LInventoryValue
    FROM dbo.Item AS i
    INNER JOIN #RecalcResult AS rr
        ON rr.ItemId = i.ItemId;

    SELECT @@ROWCOUNT AS UpdatedItemRowCount;

    SET @FinishMessage =
        'RecalcQAV run finished. Updated item cache rows = ' + CONVERT(VARCHAR(20), @@ROWCOUNT) + '.';

    RAISERROR('%s', 0, 1, @FinishMessage) WITH NOWAIT;

    -- Section 7. Optionally mark the processed recalculation log rows as deleted.
    IF @RunMode = 'RECALC_LOG' AND @MarkProcessedRecalcLogDeleted = 1
    BEGIN
        UPDATE rl
        SET rl.IsDeleted = 1
        FROM dbo.RecalculationLog AS rl
        INNER JOIN #TargetItems AS ti
            ON ti.ItemId = rl.ItemId
        WHERE ISNULL(rl.IsDeleted, 0) = 0;

        SELECT @@ROWCOUNT AS RecalculationLogRowsMarkedDeleted;
    END;

    -- Section 8. Return the recalculated item values for spot-checking.
    SELECT TOP (200)
        rr.ItemId,
        rr.BeginDate,
        rr.LCloseQty,
        rr.LAvgCost,
        rr.LInventoryValue
    FROM #RecalcResult AS rr
    ORDER BY rr.ItemId;
END

