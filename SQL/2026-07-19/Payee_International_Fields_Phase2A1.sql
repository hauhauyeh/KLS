IF COL_LENGTH('dbo.Payee', 'AddressLine2') IS NULL
BEGIN
    ALTER TABLE dbo.Payee ADD AddressLine2 NVARCHAR(255) NULL;
END;

IF COL_LENGTH('dbo.Payee', 'CountryCode') IS NULL
BEGIN
    ALTER TABLE dbo.Payee ADD CountryCode NVARCHAR(2) NULL;
END;

IF COL_LENGTH('dbo.Payee', 'Continent') IS NULL
BEGIN
    ALTER TABLE dbo.Payee ADD Continent NVARCHAR(50) NULL;
END;

IF COL_LENGTH('dbo.Payee', 'Province') IS NULL
BEGIN
    ALTER TABLE dbo.Payee ADD Province NVARCHAR(100) NULL;
END;

IF COL_LENGTH('dbo.Payee', 'PostalCode') IS NULL
BEGIN
    ALTER TABLE dbo.Payee ADD PostalCode NVARCHAR(30) NULL;
END;

IF COL_LENGTH('dbo.Payee', 'CurrencyCode') IS NULL
BEGIN
    ALTER TABLE dbo.Payee ADD CurrencyCode NVARCHAR(3) NULL;
END;

IF COL_LENGTH('dbo.Payee', 'Locale') IS NULL
BEGIN
    ALTER TABLE dbo.Payee ADD Locale NVARCHAR(20) NULL;
END;

IF COL_LENGTH('dbo.Payee', 'Timezone') IS NULL
BEGIN
    ALTER TABLE dbo.Payee ADD Timezone NVARCHAR(100) NULL;
END;

IF COL_LENGTH('dbo.Payee', 'TaxRegistrationNumber') IS NULL
BEGIN
    ALTER TABLE dbo.Payee ADD TaxRegistrationNumber NVARCHAR(100) NULL;
END;
