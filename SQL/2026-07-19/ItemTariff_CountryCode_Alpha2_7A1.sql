SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

IF OBJECT_ID('dbo.ItemTariff', 'U') IS NULL
BEGIN
    THROW 50000, 'dbo.ItemTariff table does not exist.', 1;
END;

IF COL_LENGTH('dbo.ItemTariff', 'CountryCode') IS NULL
BEGIN
    THROW 50000, 'dbo.ItemTariff.CountryCode column does not exist.', 1;
END;

IF OBJECT_ID('dbo.Country', 'U') IS NULL
   OR COL_LENGTH('dbo.Country', 'ISOAlpha2') IS NULL
   OR COL_LENGTH('dbo.Country', 'ISOAlpha3') IS NULL
BEGIN
    THROW 50000, 'dbo.Country canonical alpha-2/alpha-3 columns are required before item tariff migration.', 1;
END;

-- Map any legacy alpha-3 tariff country codes to canonical alpha-2 before shrinking the column.
UPDATE it
SET CountryCode = c.ISOAlpha2
FROM dbo.ItemTariff it
INNER JOIN dbo.Country c ON UPPER(LTRIM(RTRIM(it.CountryCode))) = UPPER(LTRIM(RTRIM(c.ISOAlpha3)))
WHERE LEN(LTRIM(RTRIM(it.CountryCode))) = 3;

IF EXISTS (
    SELECT 1
    FROM dbo.ItemTariff it
    LEFT JOIN dbo.Country c ON UPPER(LTRIM(RTRIM(it.CountryCode))) = UPPER(LTRIM(RTRIM(c.ISOAlpha2)))
    WHERE LEN(LTRIM(RTRIM(it.CountryCode))) <> 2
       OR c.CountryId IS NULL
)
BEGIN
    THROW 50000, 'ItemTariff.CountryCode contains values that cannot be mapped to canonical ISO alpha-2 countries.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'dbo'
      AND TABLE_NAME = 'ItemTariff'
      AND COLUMN_NAME = 'CountryCode'
      AND (DATA_TYPE <> 'char' OR CHARACTER_MAXIMUM_LENGTH <> 2)
)
BEGIN
    ALTER TABLE dbo.ItemTariff ALTER COLUMN CountryCode CHAR(2) NOT NULL;
END;

COMMIT TRANSACTION;
GO
