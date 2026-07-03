-- Filtered UNIQUE index: at most one ACTIVE unit per (item, ratio).
-- Prevents duplicate active ratios (e.g. two ÷6 units on one item) and a second (1,1) per item.
-- WHERE Inactive = 0 so the inactivate-then-add workflow still works (an inactivated ÷6 does not block a new ÷6).
-- Data verified clean 2026-07-02 (0 active dup ratios) before creating.
-- Filtered indexes require these SET options ON at CREATE time (sqlcmd defaults QUOTED_IDENTIFIER/ARITHABORT off).
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ARITHABORT ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = 'UX_ItemUnit_Ratio' AND object_id = OBJECT_ID('dbo.ItemUnit'))
BEGIN
    CREATE UNIQUE INDEX UX_ItemUnit_Ratio
        ON dbo.ItemUnit (ItemId, MultipleToBase, FactorToBase)
        WHERE Inactive = 0;
END
GO
