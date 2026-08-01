SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
    2026-08-01  Employee Email -> SystemUser.Email

    Enforces a unique email across admin logins, backing the application-level
    duplicate check in EmployeesController.Create/Update.

    Filtered on "Email IS NOT NULL" so the existing rows with no email (and any
    future employee saved without one) do not collide with each other.

    Column collation is SQL_Latin1_General_CP1_CI_AS, so the uniqueness is
    already case-insensitive: a@b.com and A@B.com are treated as duplicates.

    Rollback: SystemUser_EmailUniqueIndex_rollback.sql
*/

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_SystemUser_Email' AND object_id = OBJECT_ID('dbo.SystemUser'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX UX_SystemUser_Email
        ON dbo.SystemUser (Email)
        WHERE Email IS NOT NULL;
END
GO
