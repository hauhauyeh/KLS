SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================
-- 2026-06-29 (Plan 2 — purchase-entry readiness coach):
--   Seed the ITEM_USE_VOLUMEDUTY gating flag. It controls whether the purchase-entry duty/volume
--   allocation readiness coach is shown (per-row missing-data chips + coverage banner).
--   Default 'false' for KLS (no coach). Set 'true' per client that allocates landed cost by
--   volume/duty (e.g. GlobalTaste-style). INDEPENDENT of the FIFO gate ITEM_USE_EXPIRYDATE.
--   Idempotent: re-running does nothing if the key already exists.
--   Rollback: Seed_SystemSetting_ITEM_USE_VOLUMEDUTY_rollback.sql
-- =============================================================================================

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = 'ITEM_USE_VOLUMEDUTY')
BEGIN
    INSERT INTO dbo.SystemSetting (SettingKey, SettingValue, DataType, Description, CreatedAt)
    VALUES (
        'ITEM_USE_VOLUMEDUTY',
        'false',
        'bit',
        'If true, show the purchase-entry duty/volume allocation readiness coach (per-row missing-data chips + coverage banner). For clients that allocate shipment landed cost by item volume/duty. Independent of FIFO ITEM_USE_EXPIRYDATE.',
        GETDATE()
    );
END
GO
