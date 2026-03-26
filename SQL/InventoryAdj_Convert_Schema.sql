-- Add Direction column for Convert/Repack adjustment type
-- Direction: 'S' = Source, 'D' = Destination, NULL = legacy adj types (Q, V, B, etc.)

ALTER TABLE TempInventoryAdj ADD Direction VARCHAR(1) NULL;
ALTER TABLE InventoryAdjDetail ADD Direction VARCHAR(1) NULL;
GO
