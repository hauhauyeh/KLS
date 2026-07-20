SET XACT_ABORT ON;

BEGIN TRANSACTION;

IF OBJECT_ID('dbo.Country', 'U') IS NULL
BEGIN
    THROW 50000, 'dbo.Country does not exist. Cannot create Country_LegacyAlpha3 backup.', 1;
END;

IF COL_LENGTH('dbo.Country', 'ISOAlpha2') IS NULL
BEGIN
    IF OBJECT_ID('dbo.Country_LegacyAlpha3', 'U') IS NULL
    BEGIN
        EXEC sp_rename 'dbo.Country', 'Country_LegacyAlpha3';
    END
    ELSE
    BEGIN
        DECLARE @CurrentCountryRows INT;
        DECLARE @LegacyCountryRows INT;

        SELECT @CurrentCountryRows = COUNT(*) FROM dbo.Country;
        SELECT @LegacyCountryRows = COUNT(*) FROM dbo.Country_LegacyAlpha3;

        IF @LegacyCountryRows < @CurrentCountryRows
        BEGIN
            THROW 50001, 'dbo.Country_LegacyAlpha3 already exists but has fewer rows than dbo.Country.', 1;
        END;

        DROP TABLE dbo.Country;
    END;
END;

IF OBJECT_ID('dbo.Country', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Country
    (
        CountryId INT IDENTITY(1,1) NOT NULL,
        CountryCode CHAR(3) NOT NULL,
        CountryName NVARCHAR(200) NOT NULL,
        ISOAlpha2 CHAR(2) NOT NULL,
        ISOAlpha3 CHAR(3) NOT NULL,
        NumericCode CHAR(3) NULL,
        CallingCode NVARCHAR(16) NULL,
        Continent NVARCHAR(50) NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_Country_IsActive DEFAULT (1),
        SortOrder INT NULL,
        CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Country_CreatedAt DEFAULT (SYSUTCDATETIME()),
        UpdatedAt DATETIME2(0) NULL,
        CONSTRAINT PK_Country PRIMARY KEY CLUSTERED (CountryId),
        CONSTRAINT UQ_Country_CountryCode UNIQUE (CountryCode),
        CONSTRAINT UQ_Country_ISOAlpha2 UNIQUE (ISOAlpha2),
        CONSTRAINT UQ_Country_ISOAlpha3 UNIQUE (ISOAlpha3),
        CONSTRAINT CK_Country_CountryCode_ISOAlpha3 CHECK (CountryCode = ISOAlpha3)
    );
END;

COMMIT TRANSACTION;
