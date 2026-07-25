-- ItemQuote index/schema baseline for ItemQuote Manager Phase 4A.
-- Captured from local KLS_2026 on 2026-07-25 before adding quote guardrail indexes.

-- Current indexes:
-- IndexName: PK_ItemQuote
-- Type: CLUSTERED
-- IsUnique: 1
-- HasFilter: 0
-- FilterDefinition: NULL
-- KeyColumns: ItemQuoteId

-- Data checks:
-- Duplicate groups by PayeeId + ItemUnitId: 0
-- Null key rows where PayeeId or ItemUnitId is NULL: 0
-- Total rows: 32270

-- Trigger/FK notes:
-- Trigger: TRG_Delete_HasOwnList on dbo.ItemQuote.
-- It updates Customer.HasOwnList after ItemQuote insert/delete.
-- No foreign keys reference or originate from dbo.ItemQuote in local KLS_2026.

-- Re-run baseline checks:
SELECT i.name AS IndexName,
       i.type_desc,
       i.is_unique,
       i.has_filter,
       i.filter_definition,
       STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal) AS KeyColumns
FROM sys.indexes i
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID('dbo.ItemQuote')
  AND ic.key_ordinal > 0
GROUP BY i.name, i.type_desc, i.is_unique, i.has_filter, i.filter_definition
ORDER BY i.name;

SELECT COUNT(*) AS DuplicateGroups
FROM (
    SELECT PayeeId, ItemUnitId
    FROM dbo.ItemQuote
    GROUP BY PayeeId, ItemUnitId
    HAVING COUNT(*) > 1
) d;

SELECT COUNT(*) AS NullKeyRows
FROM dbo.ItemQuote
WHERE PayeeId IS NULL OR ItemUnitId IS NULL;

SELECT SUM(row_count) AS TotalRows
FROM sys.dm_db_partition_stats
WHERE object_id = OBJECT_ID('dbo.ItemQuote')
  AND index_id IN (0, 1);
