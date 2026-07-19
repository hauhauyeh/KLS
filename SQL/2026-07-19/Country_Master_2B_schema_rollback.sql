SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF OBJECT_ID('dbo.Country', 'U') IS NOT NULL
   AND COL_LENGTH('dbo.Country', 'ISOAlpha2') IS NOT NULL
BEGIN
    DROP TABLE dbo.Country;
END;

IF OBJECT_ID('dbo.Country_LegacyAlpha3', 'U') IS NOT NULL
   AND OBJECT_ID('dbo.Country', 'U') IS NULL
BEGIN
    EXEC sp_rename 'dbo.Country_LegacyAlpha3', 'Country';
END;

COMMIT TRANSACTION;
