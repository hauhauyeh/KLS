-- ItemImage_SourceFolder_Report.sql
-- Run on production DB to identify orphan ItemIds in the source image folder.
-- Pass the list of ItemIds found in the source folder to check which don't exist.
--
-- Usage: After scanning the source folder for unique ItemIds,
-- paste them into the temp table below and run this script.

SET QUOTED_IDENTIFIER ON;

-- Example: populate #SourceItemIds from your source folder scan
-- In practice, generate this list from: ls itemimages/ | grep -oP '^\d+' | sort -n | uniq
CREATE TABLE #SourceItemIds (ItemId INT);

-- INSERT INTO #SourceItemIds VALUES (1),(4),(5),...  -- paste your list here

-- Find orphans (in source folder but NOT in Item table)
SELECT s.ItemId AS OrphanItemId
FROM #SourceItemIds s
LEFT JOIN Item i ON s.ItemId = i.ItemId
WHERE i.ItemId IS NULL
ORDER BY s.ItemId;

DROP TABLE #SourceItemIds;
