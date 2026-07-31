/*
    WebClientExperienceJson_seed.sql
    2026-07-29: Optional local seed for backend-served web client profile config.

    Deploy only with explicit approval.
    Rollback: WebClientExperienceJson_seed_rollback.sql
*/
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DECLARE @SettingKey nvarchar(100) = N'WEB_CLIENT_EXPERIENCE_JSON';
DECLARE @ProfileJson nvarchar(max) = N'{}';

IF ISJSON(@ProfileJson) <> 1
    THROW 51060, 'WEB_CLIENT_EXPERIENCE_JSON seed payload is not valid JSON.', 1;

IF EXISTS (SELECT 1 FROM dbo.SystemSetting WHERE SettingKey = @SettingKey)
    THROW 51061, 'WEB_CLIENT_EXPERIENCE_JSON already exists. Review current value before updating manually.', 1;

INSERT INTO dbo.SystemSetting
(
    SettingKey,
    SettingValue,
    DataType,
    Description,
    CreatedAt
)
VALUES
(
    @SettingKey,
    @ProfileJson,
    N'json',
    N'Web client experience profile JSON',
    GETUTCDATE()
);

COMMIT TRANSACTION;

PRINT 'WEB_CLIENT_EXPERIENCE_JSON seed inserted.';
