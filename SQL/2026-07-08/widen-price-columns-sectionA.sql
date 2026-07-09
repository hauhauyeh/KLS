-- =============================================================================
-- widen-price-columns-sectionA.sql   (4-decimal pricing — Section A, Phase 1)
-- Widen 40 price columns DECIMAL(18,2) -> DECIMAL(18,4). Behavior-INERT: values
-- preserved, NO rounding change, NO display change. All 40 are NULLable (verified).
-- Single source of truth = #cols (40 rows). Idempotent (skips columns already
-- scale 4). Self-validating: FAILS (THROW) if scale/index/value/over-2dp checks fail.
--   * Auto-created stats on target columns are DROPPED first (auto-recreate on next
--     query) so no ALTER is blocked by an auto stat (plan stats note).
--   * A read-only existence/drift guard runs BEFORE the destructive block: it aborts
--     (THROW) if IX_PurchaseDetail_PurchaseId_ItemId is missing (environment mismatch)
--     or differs from the verified all-default definition — keys, includes, uniqueness,
--     filter, AND options (fill_factor 0, PAD OFF, row/page locks ON, compression NONE).
--     Running it before TRY means its THROW can never trip the CATCH index-restore.
--   * The destructive drop->widen->recreate is wrapped in TRY/CATCH: on any ALTER
--     failure the dropped index is RESTORED before re-raising (the guard proved it
--     existed, so restoring is always correct) — the script can never exit with it missing.
-- Precheck/rationale: plan-4dp-sectionA-db-widen.md. Rollback: *_rollback.sql.
-- ** USE [KLS_2026] is LOCAL-DEV ONLY — for prod set the target DB context. **
-- Sch-M lock: SalesDetail (776K rows) is the long pole; run server-down.
-- =============================================================================
USE [KLS_2026];
GO
-- ALTER TABLE on a table carrying a filtered index / indexed view / computed-column
-- index (e.g. ItemUnit) requires the FULL indexed-object SET block, or it fails with
-- Msg 1934. Our failure named only QUOTED_IDENTIFIER (sqlcmd defaults it OFF; the rest
-- were already correct here) — but we set the complete documented set so the script is
-- client-independent (SSMS / other drivers differ, notably ARITHABORT). These persist
-- for the connection across the GO below.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ---- driver: the 40 target price columns (all NULLable) ---------------------
IF OBJECT_ID('tempdb..#cols') IS NOT NULL DROP TABLE #cols;
CREATE TABLE #cols (Seq INT IDENTITY(1,1), TableName sysname, ColName sysname);
INSERT INTO #cols (TableName, ColName) VALUES
 ('CartItem','UnitPrice'),('MarketOrderItem','UnitPrice'),('SalesDetailAlloc','UnitCost'),
 ('SalesQuoteDetail','UnitPrice'),('TempSalesQuote','UnitPrice'),('TempInventoryAdj','NewPrice'),
 ('PromotionBogo','PromoPrice'),('TempBombSales','UnitPrice'),('TempBombSales','OrgPrice'),
 ('TempPurchase','BillPrice'),('TempPurchase','FinalPrice'),('TempPurchase','OrgPrice'),('TempPurchase','LandedCost'),
 ('TempItemQuote','NewPrice'),('TempItemQuote','OldPrice'),('TempItemQuote','TargetPrice'),
 ('OpenBalanceInv','Price'),('TempSales','UnitPrice'),('TempSales','OrgPrice'),
 ('Item','NCost1'),('Item','NCost2'),('Item','TCost1'),('Item','TCost2'),
 ('InventoryAdjDetail','NewPrice'),
 ('ItemUnit','P1'),('ItemUnit','MSRP'),('ItemUnit','MarketPrice'),('ItemUnit','RecentCost'),('ItemUnit','FreightCost'),
 ('ItemQuote','TargetPrice'),('ItemQuote','NewPrice'),('ItemQuote','OldPrice'),
 ('PurchaseOrderDetail','BillPrice'),('PurchaseOrderDetail','FinalPrice'),
 -- PurchaseDetail (index handled inside TRY) then SalesDetail LAST (biggest table):
 ('PurchaseDetail','BillPrice'),('PurchaseDetail','FinalPrice'),('PurchaseDetail','OrgPrice'),('PurchaseDetail','LandedCost'),
 ('SalesDetail','UnitPrice'),('SalesDetail','OrgPrice');

DECLARE @n INT = (SELECT COUNT(*) FROM #cols);
IF @n <> 40 BEGIN RAISERROR('Driver has %d rows, expected 40 — abort.', 16, 1, @n); RETURN; END
-- sanity: every driver column must exist, be decimal, and be NULLable
IF EXISTS (SELECT 1 FROM #cols x LEFT JOIN sys.columns c
             ON c.object_id = OBJECT_ID('dbo.'+x.TableName) AND c.name = x.ColName
           LEFT JOIN sys.types ty ON ty.user_type_id = c.user_type_id
           WHERE c.column_id IS NULL OR ty.name NOT IN ('decimal','numeric') OR c.is_nullable = 0)
BEGIN RAISERROR('A driver column is missing / non-decimal / NOT NULL — abort.', 16, 1); RETURN; END

DECLARE @t sysname, @c sysname, @sql nvarchar(max), @sname sysname;

-- ---- BEFORE value aggregates (read-only; proves values are preserved) -------
IF OBJECT_ID('tempdb..#agg') IS NOT NULL DROP TABLE #agg;
CREATE TABLE #agg (Phase CHAR(6), TableName sysname, ColName sysname,
                   Cnt BIGINT, Sm DECIMAL(38,6), Mn DECIMAL(38,6), Mx DECIMAL(38,6), Over2 BIGINT);
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, ColName FROM #cols ORDER BY Seq;
OPEN cur; FETCH NEXT FROM cur INTO @t, @c;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @sql = N'INSERT INTO #agg SELECT ''BEFORE'', @t, @c, COUNT(*),
      SUM(CAST('+QUOTENAME(@c)+N' AS DECIMAL(38,6))), MIN('+QUOTENAME(@c)+N'), MAX('+QUOTENAME(@c)+N'),
      SUM(CASE WHEN '+QUOTENAME(@c)+N' <> ROUND('+QUOTENAME(@c)+N',2) THEN 1 ELSE 0 END)
      FROM dbo.'+QUOTENAME(@t)+N';';
  EXEC sp_executesql @sql, N'@t sysname, @c sysname', @t=@t, @c=@c;
  FETCH NEXT FROM cur INTO @t, @c;
END
CLOSE cur; DEALLOCATE cur;

-- ---- WIDEN (fail-safe): [guard] -> drop stats -> drop index -> widen -> recreate
-- (a) is READ-ONLY and runs BEFORE the TRY: it may THROW, and keeping it out of the TRY
--     means its abort can never trip the CATCH index-restore below (a missing index must
--     NOT be "restored" into existence). (b)-(e) are the destructive steps, wrapped in
--     TRY/CATCH so a blocked ALTER can never leave the index dropped.
--     (@po/@idxId captured in the guard, reused at drop.)
DECLARE @po INT = OBJECT_ID('dbo.PurchaseDetail'), @idxId INT, @uniq BIT, @typ sysname, @filt nvarchar(max),
        @ff INT, @pad BIT, @rl BIT, @pl BIT, @comp INT;

-- (a) EXISTENCE + DRIFT GUARD — abort (THROW) if the index is missing (environment
--     mismatch: this script assumes the verified existing index) or differs from the
--     verified all-default definition, rather than silently create / overwrite it.
SELECT @idxId=index_id, @uniq=is_unique, @typ=type_desc, @filt=filter_definition,
       @ff=fill_factor, @pad=is_padded, @rl=allow_row_locks, @pl=allow_page_locks
  FROM sys.indexes WHERE name='IX_PurchaseDetail_PurchaseId_ItemId' AND object_id=@po;
IF @idxId IS NULL
  THROW 50000, 'IX_PurchaseDetail_PurchaseId_ItemId is missing on dbo.PurchaseDetail — environment mismatch (this script assumes the verified existing index). Aborting before any ALTER.', 1;
SELECT @comp = MAX(data_compression) FROM sys.partitions WHERE object_id=@po AND index_id=@idxId;
DECLARE @keyN INT = (SELECT COUNT(*) FROM sys.index_columns WHERE object_id=@po AND index_id=@idxId AND is_included_column=0);
DECLARE @keyBad INT = (SELECT COUNT(*) FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
    WHERE ic.object_id=@po AND ic.index_id=@idxId AND ic.is_included_column=0
      AND NOT ((ic.key_ordinal=1 AND c.name='PurchaseId') OR (ic.key_ordinal=2 AND c.name='ItemId')));
DECLARE @inclN INT = (SELECT COUNT(*) FROM sys.index_columns WHERE object_id=@po AND index_id=@idxId AND is_included_column=1);
DECLARE @inclBad INT = (SELECT COUNT(*) FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
    WHERE ic.object_id=@po AND ic.index_id=@idxId AND ic.is_included_column=1 AND c.name NOT IN ('PurchaseDetailId','FinalQty','FinalPrice'));
-- drift check covers keys/includes AND every option the header claims verified
-- (uniqueness, filter, fill_factor, PAD_INDEX, row/page locks, data compression):
IF @typ<>'NONCLUSTERED' OR @uniq<>0 OR @filt IS NOT NULL OR @keyN<>2 OR @keyBad>0 OR @inclN<>3 OR @inclBad>0
   OR @ff<>0 OR @pad<>0 OR @rl<>1 OR @pl<>1 OR @comp<>0
  THROW 50000, 'IX_PurchaseDetail_PurchaseId_ItemId differs from the verified definition (keys/includes/uniqueness/filter/fill_factor/PAD/locks/compression) — aborting so a drifted index is not silently overwritten. Reconcile the recreate first.', 1;

BEGIN TRY

  -- (b) drop AUTO-created stats on target columns (auto-recreate on next query;
  --     prevents an ALTER being blocked by an auto stat; never touches user/index stats).
  DECLARE stat_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT t.name, s.name
    FROM sys.stats s
    JOIN sys.stats_columns sc ON sc.object_id=s.object_id AND sc.stats_id=s.stats_id
    JOIN sys.columns c ON c.object_id=sc.object_id AND c.column_id=sc.column_id
    JOIN sys.tables t ON t.object_id=s.object_id
    JOIN #cols x ON x.TableName=t.name AND x.ColName=c.name
    WHERE s.auto_created=1 AND s.user_created=0;
  OPEN stat_cur; FETCH NEXT FROM stat_cur INTO @t, @sname;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @sql = N'DROP STATISTICS dbo.'+QUOTENAME(@t)+N'.'+QUOTENAME(@sname)+N';';
    EXEC sp_executesql @sql;
    PRINT '  dropped auto-stat '+@t+'.'+@sname;
    FETCH NEXT FROM stat_cur INTO @t, @sname;
  END
  CLOSE stat_cur; DEALLOCATE stat_cur;

  -- (c) drop the index (guard above proved it exists and matches the verified definition)
  DROP INDEX IX_PurchaseDetail_PurchaseId_ItemId ON dbo.PurchaseDetail;

  DECLARE cur2 CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, ColName FROM #cols ORDER BY Seq;  -- small -> big
  OPEN cur2; FETCH NEXT FROM cur2 INTO @t, @c;
  WHILE @@FETCH_STATUS = 0
  BEGIN
    IF (SELECT scale FROM sys.columns WHERE object_id=OBJECT_ID('dbo.'+@t) AND name=@c) <> 4
    BEGIN
      SET @sql = N'ALTER TABLE dbo.'+QUOTENAME(@t)+N' ALTER COLUMN '+QUOTENAME(@c)+N' DECIMAL(18,4) NULL;';
      EXEC sp_executesql @sql;
      PRINT '  widened '+@t+'.'+@c;
    END
    FETCH NEXT FROM cur2 INTO @t, @c;
  END
  CLOSE cur2; DEALLOCATE cur2;

  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_PurchaseDetail_PurchaseId_ItemId'
                   AND object_id=OBJECT_ID('dbo.PurchaseDetail'))
      CREATE NONCLUSTERED INDEX IX_PurchaseDetail_PurchaseId_ItemId
          ON dbo.PurchaseDetail (PurchaseId, ItemId)
          INCLUDE (PurchaseDetailId, FinalQty, FinalPrice);
END TRY
BEGIN CATCH
  -- restore the index if the failure happened after it was dropped, then re-raise
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_PurchaseDetail_PurchaseId_ItemId'
                   AND object_id=OBJECT_ID('dbo.PurchaseDetail'))
      CREATE NONCLUSTERED INDEX IX_PurchaseDetail_PurchaseId_ItemId
          ON dbo.PurchaseDetail (PurchaseId, ItemId)
          INCLUDE (PurchaseDetailId, FinalQty, FinalPrice);
  PRINT '*** widen FAILED — IX_PurchaseDetail_PurchaseId_ItemId restored (if it had been dropped). Re-raising.';
  THROW;
END CATCH

-- ---- AFTER value aggregates -------------------------------------------------
DECLARE cur3 CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, ColName FROM #cols ORDER BY Seq;
OPEN cur3; FETCH NEXT FROM cur3 INTO @t, @c;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @sql = N'INSERT INTO #agg SELECT ''AFTER'', @t, @c, COUNT(*),
      SUM(CAST('+QUOTENAME(@c)+N' AS DECIMAL(38,6))), MIN('+QUOTENAME(@c)+N'), MAX('+QUOTENAME(@c)+N'),
      SUM(CASE WHEN '+QUOTENAME(@c)+N' <> ROUND('+QUOTENAME(@c)+N',2) THEN 1 ELSE 0 END)
      FROM dbo.'+QUOTENAME(@t)+N';';
  EXEC sp_executesql @sql, N'@t sysname, @c sysname', @t=@t, @c=@c;
  FETCH NEXT FROM cur3 INTO @t, @c;
END
CLOSE cur3; DEALLOCATE cur3;

-- ---- VALIDATION — show grids, then FAIL (THROW) if anything is off ----------
-- (1) every target column now scale 4
DECLARE @bad INT = (SELECT COUNT(*) FROM #cols x
    JOIN sys.columns c ON c.object_id=OBJECT_ID('dbo.'+x.TableName) AND c.name=x.ColName WHERE c.scale <> 4);
-- (2) index restored
DECLARE @idxMissing INT = CASE WHEN EXISTS (SELECT 1 FROM sys.indexes
    WHERE name='IX_PurchaseDetail_PurchaseId_ItemId' AND object_id=OBJECT_ID('dbo.PurchaseDetail')) THEN 0 ELSE 1 END;
-- (3) values UNCHANGED before vs after
IF OBJECT_ID('tempdb..#mm') IS NOT NULL DROP TABLE #mm;
SELECT b.TableName, b.ColName, b.Cnt BefCnt, a.Cnt AftCnt, b.Sm BefSum, a.Sm AftSum,
       b.Mn BefMin, a.Mn AftMin, b.Mx BefMax, a.Mx AftMax
INTO #mm
FROM #agg b JOIN #agg a ON a.TableName=b.TableName AND a.ColName=b.ColName AND a.Phase='AFTER'
WHERE b.Phase='BEFORE'
  AND (b.Cnt<>a.Cnt OR ISNULL(b.Sm,0)<>ISNULL(a.Sm,0) OR ISNULL(b.Mn,0)<>ISNULL(a.Mn,0) OR ISNULL(b.Mx,0)<>ISNULL(a.Mx,0));
DECLARE @mm INT = (SELECT COUNT(*) FROM #mm);
-- (4) any column with >2dp data (Phase 1 — none should)
DECLARE @ov INT = (SELECT COUNT(*) FROM #agg WHERE Phase='AFTER' AND Over2 > 0);

SELECT [Grid]='(3) VALUE MISMATCH (must be empty)', * FROM #mm;
SELECT [Grid]='(4) OVER-2DP (must be empty)', TableName, ColName, Over2 FROM #agg WHERE Phase='AFTER' AND Over2 > 0;

IF @bad = 0 AND @idxMissing = 0 AND @mm = 0 AND @ov = 0
  PRINT 'PASS: Section A widen validated — all 40 scale 4, index restored, values preserved, no >2dp data.';
ELSE
BEGIN
  DECLARE @vmsg nvarchar(400) = CONCAT('SECTION A VALIDATION FAILED — notScale4=', @bad,
      ', indexMissing=', @idxMissing, ', valueMismatch=', @mm, ', over2dp=', @ov, '. Inspect grids (3)/(4).');
  THROW 50000, @vmsg, 1;
END

DROP TABLE #cols; DROP TABLE #agg; DROP TABLE #mm;
GO
