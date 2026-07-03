-- ============================================================================
-- Rollback -- remove MultipleToBase from ItemUnit
-- Reverses ItemUnit_AddMultipleToBase.sql exactly (constraints, then default, then column).
-- Safe: the column is inert (DEFAULT 1). Nothing depends on it until Phase B code ships;
-- do NOT run this once Phase B/UI is live (rows may hold MultipleToBase > 1).
-- ============================================================================

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ItemUnit_Ratio_OneSideOne')
    ALTER TABLE dbo.ItemUnit DROP CONSTRAINT CK_ItemUnit_Ratio_OneSideOne;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ItemUnit_MultipleToBase_Positive')
    ALTER TABLE dbo.ItemUnit DROP CONSTRAINT CK_ItemUnit_MultipleToBase_Positive;
GO

IF EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = 'DF_ItemUnit_MultipleToBase')
    ALTER TABLE dbo.ItemUnit DROP CONSTRAINT DF_ItemUnit_MultipleToBase;
GO

IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.ItemUnit') AND name = 'MultipleToBase')
    ALTER TABLE dbo.ItemUnit DROP COLUMN MultipleToBase;
GO
