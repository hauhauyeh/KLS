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
    THROW 50000, 'dbo.Country canonical alpha-2/alpha-3 columns are required before rollback.', 1;
END;

IF EXISTS (
    SELECT 1
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'dbo'
      AND TABLE_NAME = 'ItemTariff'
      AND COLUMN_NAME = 'CountryCode'
      AND (DATA_TYPE <> 'char' OR CHARACTER_MAXIMUM_LENGTH <> 3)
)
BEGIN
    ALTER TABLE dbo.ItemTariff ALTER COLUMN CountryCode CHAR(3) NOT NULL;
END;

-- Restore the legacy tariff country storage shape.
UPDATE it
SET CountryCode = c.ISOAlpha3
FROM dbo.ItemTariff it
INNER JOIN dbo.Country c ON UPPER(LTRIM(RTRIM(it.CountryCode))) = UPPER(LTRIM(RTRIM(c.ISOAlpha2)))
WHERE LEN(LTRIM(RTRIM(it.CountryCode))) = 2;

COMMIT TRANSACTION;
GO
