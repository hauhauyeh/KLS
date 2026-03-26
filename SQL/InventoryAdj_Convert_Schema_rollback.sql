-- Rollback: Remove Direction column from Convert/Repack support

ALTER TABLE TempInventoryAdj DROP COLUMN Direction;
ALTER TABLE InventoryAdjDetail DROP COLUMN Direction;
GO
