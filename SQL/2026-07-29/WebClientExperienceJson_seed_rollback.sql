/*
    WebClientExperienceJson_seed_rollback.sql
    2026-07-29: Conservative rollback for WebClientExperienceJson_seed.sql.

    Deletes only the exact empty-profile seed inserted by the paired seed script.
*/
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @SettingKey nvarchar(100) = N'WEB_CLIENT_EXPERIENCE_JSON';
DECLARE @SeedProfileJson nvarchar(max) = N'{}';

IF EXISTS (
    SELECT 1
    FROM dbo.SystemSetting
    WHERE SettingKey = @SettingKey
      AND ISNULL(SettingValue, N'') <> @SeedProfileJson
)
    THROW 51062, 'WEB_CLIENT_EXPERIENCE_JSON value differs from seed payload. Rollback aborted to avoid deleting a real profile.', 1;

DELETE FROM dbo.SystemSetting
WHERE SettingKey = @SettingKey
  AND SettingValue = @SeedProfileJson;

COMMIT TRANSACTION;

PRINT 'WEB_CLIENT_EXPERIENCE_JSON seed rollback completed.';
