-- Item_GetAllList: Add dimension columns (CaseLength, CaseWidth, CaseHeight, CaseVolumeInCubicMeter, IsVolumeManual)
-- Prerequisite: Run Dimension_AddIsVolumeManual.sql first
-- Pattern: sp_rename existing to _prev, then CREATE new version
-- Rollback: DROP Item_GetAllList, then sp_rename 'Item_GetAllList_prev', 'Item_GetAllList'

-- Step 1: Already renamed to Item_GetAllList_prev before creating new version
-- EXEC sp_rename 'Item_GetAllList', 'Item_GetAllList_prev';

-- Step 2: New version adds 5 columns to #itmtbl and SELECT:
--   CaseLength DECIMAL(18,2)
--   CaseWidth DECIMAL(18,2)
--   CaseHeight DECIMAL(18,2)
--   CaseVolumeInCubicMeter DECIMAL(18,4)
--   IsVolumeManual BIT
-- After RefillInventory in both locations.
-- CaseWeight was already in the SP.
