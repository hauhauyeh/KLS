-- =============================================================================
-- widen-price-columns-sectionA_rollback.sql   (4-decimal pricing — Section A)
-- Narrow the 40 price columns DECIMAL(18,4) -> DECIMAL(18,2).
-- ** GUARDED + ATOMIC: **
--   Phase 1 — check EVERY target column for >2dp data FIRST; a single hit aborts
--             (THROW) before anything is narrowed (no silent truncation).
--   Phase 2 — one transaction (SET XACT_ABORT ON): drop auto-stats, drop index,
--             narrow all columns, recreate index. Any failure rolls the whole thing
--             back (index + columns restored). IX recreate is byte-exact (index
--             verified all-default). Idempotent (skips columns already scale 2).
-- Safe only while NO 4dp value exists (Phase 1 enforces this).
-- ** USE [KLS_2026] is LOCAL-DEV ONLY — for prod set the target DB context. **
-- =============================================================================
USE [KLS_2026];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ---- driver: the same 40 target columns ------------------------------------
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
 ('PurchaseDetail','BillPrice'),('PurchaseDetail','FinalPrice'),('PurchaseDetail','OrgPrice'),('PurchaseDetail','LandedCost'),
 ('SalesDetail','UnitPrice'),('SalesDetail','OrgPrice');

DECLARE @n INT = (SELECT COUNT(*) FROM #cols);
IF @n <> 40 BEGIN RAISERROR('Driver has %d rows, expected 40 — abort.', 16, 1, @n); RETURN; END

DECLARE @t sysname, @c sysname, @sql nvarchar(max), @sname sysname, @found BIT;

-- ===== Phase 1: GUARD-FIRST — abort if ANY column holds >2dp data ============
DECLARE @viol nvarchar(max) = N'';
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, ColName FROM #cols ORDER BY Seq;
OPEN cur; FETCH NEXT FROM cur INTO @t, @c;
WHILE @@FETCH_STATUS = 0
BEGIN
  SET @found = 0;
  SET @sql = N'IF EXISTS (SELECT 1 FROM dbo.'+QUOTENAME(@t)+N' WHERE '+QUOTENAME(@c)+N' <> ROUND('+QUOTENAME(@c)+N',2)) SET @found = 1;';
  EXEC sp_executesql @sql, N'@found BIT OUTPUT', @found = @found OUTPUT;
  IF @found = 1 SET @viol = @viol + @t + N'.' + @c + N'; ';
  FETCH NEXT FROM cur INTO @t, @c;
END
CLOSE cur; DEALLOCATE cur;

IF @viol <> N''
BEGIN
  DECLARE @msg nvarchar(2048) = N'ROLLBACK ABORTED — >2dp data present in: ' + @viol
      + N'Narrowing would truncate real 4dp values. Nothing was changed.';
  THROW 50000, @msg, 1;
END
PRINT 'Guard passed: no column holds >2dp data — safe to narrow.';

-- ---- index drift guard: abort if IX differs from the verified definition ----
DECLARE @po INT = OBJECT_ID('dbo.PurchaseDetail'), @idxId INT, @uniq BIT, @typ sysname, @filt nvarchar(max);
SELECT @idxId=index_id, @uniq=is_unique, @typ=type_desc, @filt=filter_definition
  FROM sys.indexes WHERE name='IX_PurchaseDetail_PurchaseId_ItemId' AND object_id=@po;
IF @idxId IS NOT NULL
BEGIN
  DECLARE @keyN INT = (SELECT COUNT(*) FROM sys.index_columns WHERE object_id=@po AND index_id=@idxId AND is_included_column=0);
  DECLARE @keyBad INT = (SELECT COUNT(*) FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
      WHERE ic.object_id=@po AND ic.index_id=@idxId AND ic.is_included_column=0
        AND NOT ((ic.key_ordinal=1 AND c.name='PurchaseId') OR (ic.key_ordinal=2 AND c.name='ItemId')));
  DECLARE @inclN INT = (SELECT COUNT(*) FROM sys.index_columns WHERE object_id=@po AND index_id=@idxId AND is_included_column=1);
  DECLARE @inclBad INT = (SELECT COUNT(*) FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
      WHERE ic.object_id=@po AND ic.index_id=@idxId AND ic.is_included_column=1 AND c.name NOT IN ('PurchaseDetailId','FinalQty','FinalPrice'));
  IF @typ<>'NONCLUSTERED' OR @uniq<>0 OR @filt IS NOT NULL OR @keyN<>2 OR @keyBad>0 OR @inclN<>3 OR @inclBad>0
    THROW 50000, 'IX_PurchaseDetail_PurchaseId_ItemId differs from the verified definition — aborting so a drifted index is not silently overwritten.', 1;
END

-- ===== Phase 2: ATOMIC narrow (stats + index + all columns in one tran) ======
BEGIN TRAN;

-- drop AUTO-created stats on target columns first (auto-recreate on next query;
-- avoids an ALTER being blocked by an auto stat). Never touches user/index stats.
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
  FETCH NEXT FROM stat_cur INTO @t, @sname;
END
CLOSE stat_cur; DEALLOCATE stat_cur;

IF EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_PurchaseDetail_PurchaseId_ItemId'
             AND object_id=OBJECT_ID('dbo.PurchaseDetail'))
    DROP INDEX IX_PurchaseDetail_PurchaseId_ItemId ON dbo.PurchaseDetail;

DECLARE cur2 CURSOR LOCAL FAST_FORWARD FOR SELECT TableName, ColName FROM #cols ORDER BY Seq;
OPEN cur2; FETCH NEXT FROM cur2 INTO @t, @c;
WHILE @@FETCH_STATUS = 0
BEGIN
  IF (SELECT scale FROM sys.columns WHERE object_id=OBJECT_ID('dbo.'+@t) AND name=@c) <> 2
  BEGIN
    SET @sql = N'ALTER TABLE dbo.'+QUOTENAME(@t)+N' ALTER COLUMN '+QUOTENAME(@c)+N' DECIMAL(18,2) NULL;';
    EXEC sp_executesql @sql;
    PRINT '  narrowed '+@t+'.'+@c;
  END
  FETCH NEXT FROM cur2 INTO @t, @c;
END
CLOSE cur2; DEALLOCATE cur2;

-- byte-exact recreate (index verified all-default: non-unique, no filter,
-- fill_factor 0, PAD OFF, row/page locks ON, compression NONE)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_PurchaseDetail_PurchaseId_ItemId'
                 AND object_id=OBJECT_ID('dbo.PurchaseDetail'))
    CREATE NONCLUSTERED INDEX IX_PurchaseDetail_PurchaseId_ItemId
        ON dbo.PurchaseDetail (PurchaseId, ItemId)
        INCLUDE (PurchaseDetailId, FinalQty, FinalPrice);

COMMIT;

-- ---- validate: every target column back to scale 2, index present (FAIL loud) -
DECLARE @bad INT = (SELECT COUNT(*) FROM #cols x
    JOIN sys.columns c ON c.object_id=OBJECT_ID('dbo.'+x.TableName) AND c.name=x.ColName WHERE c.scale <> 2);
DECLARE @idxMissing INT = CASE WHEN EXISTS (SELECT 1 FROM sys.indexes
    WHERE name='IX_PurchaseDetail_PurchaseId_ItemId' AND object_id=OBJECT_ID('dbo.PurchaseDetail')) THEN 0 ELSE 1 END;
IF @bad = 0 AND @idxMissing = 0
  PRINT 'PASS: all 40 target columns back to DECIMAL(18,2), index restored.';
ELSE
BEGIN
  DECLARE @vmsg nvarchar(300) = CONCAT('ROLLBACK VALIDATION FAILED — notScale2=', @bad, ', indexMissing=', @idxMissing, '.');
  THROW 50000, @vmsg, 1;
END

DROP TABLE #cols;
GO
