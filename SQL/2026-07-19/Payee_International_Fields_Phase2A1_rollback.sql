IF COL_LENGTH('dbo.Payee', 'TaxRegistrationNumber') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Payee DROP COLUMN TaxRegistrationNumber;
END;

IF COL_LENGTH('dbo.Payee', 'Timezone') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Payee DROP COLUMN Timezone;
END;

IF COL_LENGTH('dbo.Payee', 'Locale') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Payee DROP COLUMN Locale;
END;

IF COL_LENGTH('dbo.Payee', 'CurrencyCode') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Payee DROP COLUMN CurrencyCode;
END;

IF COL_LENGTH('dbo.Payee', 'PostalCode') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Payee DROP COLUMN PostalCode;
END;

IF COL_LENGTH('dbo.Payee', 'Province') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Payee DROP COLUMN Province;
END;

IF COL_LENGTH('dbo.Payee', 'Continent') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Payee DROP COLUMN Continent;
END;

IF COL_LENGTH('dbo.Payee', 'CountryCode') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Payee DROP COLUMN CountryCode;
END;

IF COL_LENGTH('dbo.Payee', 'AddressLine2') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Payee DROP COLUMN AddressLine2;
END;
