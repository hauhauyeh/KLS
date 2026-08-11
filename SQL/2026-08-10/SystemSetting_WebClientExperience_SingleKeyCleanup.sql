/*
    SystemSetting_WebClientExperience_SingleKeyCleanup.sql

    Keeps WEB_CLIENT_EXPERIENCE_JSON as the only active web client experience
    runtime key. Company-specific override keys are backed up, then removed.

    This script does not seed or overwrite WEB_CLIENT_EXPERIENCE_JSON.
*/

SET XACT_ABORT ON;

DECLARE @GenericKey nvarchar(100) = N'WEB_CLIENT_EXPERIENCE_JSON';
DECLARE @RunId uniqueidentifier = NEWID();

IF NOT EXISTS (
    SELECT 1
    FROM dbo.SystemSetting
    WHERE SettingKey = @GenericKey
)
BEGIN
    THROW 51100, 'WEB_CLIENT_EXPERIENCE_JSON is missing. Cleanup aborted; seed/restore the generic key first.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM dbo.SystemSetting
    WHERE SettingKey = @GenericKey
      AND ISJSON(CONVERT(nvarchar(max), SettingValue)) <> 1
)
BEGIN
    THROW 51101, 'WEB_CLIENT_EXPERIENCE_JSON is not valid JSON. Cleanup aborted.', 1;
END;

PRINT 'Web client experience keys before cleanup:';

SELECT
    SettingKey,
    LEN(CONVERT(nvarchar(max), SettingValue)) AS ValueLength,
    ISJSON(CONVERT(nvarchar(max), SettingValue)) AS IsJson,
    DataType,
    Description,
    CreatedAt,
    UpdatedAt
FROM dbo.SystemSetting
WHERE SettingKey = @GenericKey
   OR SettingKey LIKE N'WEB_CLIENT_EXPERIENCE_JSON[_]%'
ORDER BY SettingKey;

BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.SystemSetting_WebClientExperienceOverrideBackup', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SystemSetting_WebClientExperienceOverrideBackup
    (
        BackupId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_SystemSetting_WebClientExperienceOverrideBackup PRIMARY KEY,
        BackupRunId uniqueidentifier NOT NULL,
        BackupAt datetime NOT NULL CONSTRAINT DF_SystemSetting_WebClientExperienceOverrideBackup_BackupAt DEFAULT (GETDATE()),
        SourceId int NOT NULL,
        SettingKey nvarchar(100) NOT NULL,
        SettingValue nvarchar(max) NULL,
        DataType nvarchar(50) NULL,
        Description nvarchar(255) NULL,
        CreatedAt datetime NULL,
        UpdatedAt datetime NULL
    );
END;

INSERT INTO dbo.SystemSetting_WebClientExperienceOverrideBackup
(
    BackupRunId,
    SourceId,
    SettingKey,
    SettingValue,
    DataType,
    Description,
    CreatedAt,
    UpdatedAt
)
SELECT
    @RunId,
    Id,
    SettingKey,
    SettingValue,
    DataType,
    Description,
    CreatedAt,
    UpdatedAt
FROM dbo.SystemSetting
WHERE SettingKey LIKE N'WEB_CLIENT_EXPERIENCE_JSON[_]%';

DELETE FROM dbo.SystemSetting
WHERE SettingKey LIKE N'WEB_CLIENT_EXPERIENCE_JSON[_]%';

COMMIT TRANSACTION;

PRINT 'Backed up override keys with BackupRunId:';
SELECT CONVERT(nvarchar(36), @RunId) AS BackupRunId;

PRINT 'Web client experience keys after cleanup:';

SELECT
    SettingKey,
    LEN(CONVERT(nvarchar(max), SettingValue)) AS ValueLength,
    ISJSON(CONVERT(nvarchar(max), SettingValue)) AS IsJson,
    DataType,
    Description,
    CreatedAt,
    UpdatedAt
FROM dbo.SystemSetting
WHERE SettingKey = @GenericKey
   OR SettingKey LIKE N'WEB_CLIENT_EXPERIENCE_JSON[_]%'
ORDER BY SettingKey;
