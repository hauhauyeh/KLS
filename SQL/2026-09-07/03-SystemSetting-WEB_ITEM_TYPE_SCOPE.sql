-- =============================================================================
-- SystemSetting seed: WEB_ITEM_TYPE_SCOPE
-- 2026-09-07 (plan-web-noninventory-catalog-v2, Slice 1)
--   Web catalog scope consumed by Web_Item_List and Web_Item_SearchInventory.
--   Values: 'Inventory' (default) | 'NonInventory' | 'All'.
--   Seeded as 'Inventory' so every existing tenant keeps today's behavior. A tenant
--   whose catalog is entirely non-inventory sets its row to 'NonInventory' (see the
--   commented UPDATE at the bottom -- run it only in that tenant's database).
--   Idempotent: safe to re-run; an existing row is never overwritten.
-- DataType 'string' follows the WEB_PORTAL_MODE convention.
-- Rollback: DELETE FROM SystemSetting WHERE SettingKey = 'WEB_ITEM_TYPE_SCOPE'
--   (both SPs fall back to 'Inventory' when the row is absent, so removing it is safe).
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = 'WEB_ITEM_TYPE_SCOPE')
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES ('WEB_ITEM_TYPE_SCOPE', 'Inventory', 'string',
            'Web catalog item scope: Inventory | NonInventory | All', GETDATE())
END
GO

-- Verify
SELECT SettingKey, SettingValue, DataType, Description
FROM dbo.SystemSetting
WHERE SettingKey = 'WEB_ITEM_TYPE_SCOPE'
GO

-- Per-tenant switch -- run ONLY in the database of a fully non-inventory client:
-- UPDATE dbo.SystemSetting
--    SET SettingValue = 'NonInventory', UpdatedAt = GETDATE()
--  WHERE SettingKey = 'WEB_ITEM_TYPE_SCOPE'
-- GO
