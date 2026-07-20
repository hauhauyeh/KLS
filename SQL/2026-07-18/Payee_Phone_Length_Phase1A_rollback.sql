IF EXISTS (
    SELECT 1
    FROM dbo.Payee
    WHERE LEN(ISNULL(Phone1, '')) > 30
       OR LEN(ISNULL(Phone2, '')) > 30
       OR LEN(ISNULL(Phone3, '')) > 30
       OR LEN(ISNULL(Phone4, '')) > 30
       OR LEN(ISNULL(Phone5, '')) > 30
       OR LEN(ISNULL(Phone6, '')) > 30
)
BEGIN
    THROW 50001, 'Rollback blocked: at least one Payee phone value is longer than 30 characters.', 1;
END;

IF COL_LENGTH('dbo.Payee', 'Phone1') IS NOT NULL
BEGIN
    ALTER TABLE dbo.Payee ALTER COLUMN Phone1 NVARCHAR(30) NULL;
    ALTER TABLE dbo.Payee ALTER COLUMN Phone2 NVARCHAR(30) NULL;
    ALTER TABLE dbo.Payee ALTER COLUMN Phone3 NVARCHAR(30) NULL;
    ALTER TABLE dbo.Payee ALTER COLUMN Phone4 NVARCHAR(30) NULL;
    ALTER TABLE dbo.Payee ALTER COLUMN Phone5 NVARCHAR(30) NULL;
    ALTER TABLE dbo.Payee ALTER COLUMN Phone6 NVARCHAR(30) NULL;
END;

