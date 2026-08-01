SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
    2026-08-01  Rollback for Payee_AddIsSystemAccount.sql

    Drops the default constraint then the column.

    Refuses while any row is flagged: dropping the column with system accounts
    present would make SYS1/SYS2 indistinguishable from real employees and they
    would immediately reappear in every list. Run SystemAccounts_Seed_rollback.sql
    first if that is what you intend.
*/

IF EXISTS (SELECT 1 FROM dbo.Payee WHERE IsSystemAccount = 1)
BEGIN
    THROW 51001, 'Rollback refused: Payee rows with IsSystemAccount = 1 still exist. Run SystemAccounts_Seed_rollback.sql first.', 1;
END
GO

IF EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = 'DF_Payee_IsSystemAccount')
    ALTER TABLE dbo.Payee DROP CONSTRAINT DF_Payee_IsSystemAccount;
GO

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.Payee') AND name = 'IsSystemAccount'
)
    ALTER TABLE dbo.Payee DROP COLUMN IsSystemAccount;
GO
