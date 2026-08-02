SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
    2026-08-01  Hidden super admin accounts - schema

    Adds Payee.IsSystemAccount, the single flag that hides an account from every
    employee-facing list, search and dropdown in the system.

    Why Payee and not Employee: two of the three list/search sources
    (Employee_SearchByTerm and Payee_SearchByTerm) query Payee with no Employee
    join at all, so a Payee column filters all of them with one predicate and no
    new joins.

    NOT NULL DEFAULT 0 means every existing row is correct immediately - no
    backfill, and no behaviour change for any customer, vendor or employee.

    Plan:     plan/hidden-super-admin-accounts-v2.md
    Rollback: Payee_AddIsSystemAccount_rollback.sql
*/

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.Payee') AND name = 'IsSystemAccount'
)
BEGIN
    ALTER TABLE dbo.Payee
        ADD IsSystemAccount BIT NOT NULL
            CONSTRAINT DF_Payee_IsSystemAccount DEFAULT (0);
END
GO
