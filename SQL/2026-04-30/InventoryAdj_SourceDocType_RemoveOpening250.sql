-- Retire the old Inventory Adj Opening mapping.
-- Inventory adjustments now use:
-- - 600 = Inventory Adj (Before Receiving)
-- - 695 = Inventory Adj Closing (After Receiving)
-- The old 250 row is no longer used by live posting logic or live journal data.

DELETE FROM dbo.SourceDocType
WHERE DocType = 'Inventory Adj Opening'
  AND DocOrder = 250;
