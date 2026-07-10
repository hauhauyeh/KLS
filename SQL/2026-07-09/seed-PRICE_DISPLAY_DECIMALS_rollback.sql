-- KLS-4DP-B-Phase2-Slice0 ROLLBACK: remove the PRICE_DISPLAY_DECIMALS SystemSetting seed.
-- Safe: only removes the single seeded key. Reverts to the pre-seed state (no such setting -> consumers
-- default to 2dp via GetByKey<int> returning default(int)=0 guarded to 2, or the SQL COALESCE fallback).
DELETE FROM dbo.SystemSetting WHERE SettingKey = 'PRICE_DISPLAY_DECIMALS';
GO
