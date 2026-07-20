SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF OBJECT_ID('dbo.Country', 'U') IS NOT NULL AND COL_LENGTH('dbo.Country', 'ISOAlpha2') IS NOT NULL
BEGIN
    UPDATE dbo.Country
    SET NumericCode = NULL,
        CallingCode = NULL,
        Continent = NULL,
        UpdatedAt = SYSUTCDATETIME();
END;

COMMIT TRANSACTION;