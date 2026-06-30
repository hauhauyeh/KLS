SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- Rollback of Seed_SystemSetting_ITEM_USE_VOLUMEDUTY.sql (2026-06-29, Plan 2).
--   Removes the ITEM_USE_VOLUMEDUTY gating flag.
-- =============================================================================================

DELETE FROM dbo.SystemSetting WHERE SettingKey = 'ITEM_USE_VOLUMEDUTY';
GO
