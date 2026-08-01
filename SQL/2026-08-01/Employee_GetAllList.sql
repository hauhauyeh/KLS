SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- Employee_GetAllList
-- HIDE_SYSTEM_ACCOUNTS 2026-08-01: excludes the hidden super admin accounts
--   (SYS1/SYS2) from the employee list screen.
--   Only change: AND p.IsSystemAccount = 0 appended to the base query's WHERE,
--   inside the dynamic string so it applies before the search/status filters.
--   No real employee carries the flag, so the list is otherwise identical at
--   every status filter.
-- Baseline: Employee_GetAllList_live_baseline.sql
-- Plan:     plan/hidden-super-admin-accounts-v2.md
-- =============================================
-- Author:      <Author,,Name>
-- Create date: <Create Date,,>
-- Description: Get list of employees with search, status filter, and sorting
-- =============================================
-- EXEC dbo.Employee_GetAllList @Search = NULL, @EmpStatus = 0, @SortField = NULL, @SortOrder = NULL
CREATE OR ALTER PROCEDURE [dbo].[Employee_GetAllList]

    @Search     NVARCHAR(100),
    @EmpStatus  BIT,
    @SortField  NVARCHAR(50),
    @SortOrder  NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qry NVARCHAR(MAX);

    -- Base Query
    SET @Qry = '
    SELECT
        p.PayeeId,
        p.PayeeName,
        p.IsClosed,
        e.FirstName,
        e.LastName,
        e.Department,
        r.RoleName,
        e.HasOutsideAccess,
        CONVERT(
            BIT,
            CASE
                WHEN (u.Username IS NOT NULL AND p.IsClosed = 0)
                    THEN 1
                ELSE 0
            END
        ) AS CanLogin
    FROM
        Payee AS p
        INNER JOIN Employee AS e
            ON e.PayeeId = p.PayeeId
        LEFT JOIN SystemUser AS u
            ON p.PayeeId = u.PayeeId
        LEFT JOIN SystemRole AS r
            ON r.SystemRoleId = u.SystemRoleId
    WHERE
        p.PayeeType = ''E''
        AND p.IsSystemAccount = 0';

    -- Search Filter
    IF @Search IS NOT NULL
    BEGIN
        SET @Search = REPLACE(@Search, '''', '''''');
        SET @Qry += ' AND p.PayeeName LIKE ''%' + CONVERT(NVARCHAR(100), @Search) + '%'' ';
    END

    -- Status Filter
    IF @EmpStatus IS NOT NULL
		SET @Qry += ' AND p.IsClosed = ' + CONVERT(VARCHAR, @EmpStatus);

    IF @SortField IS NOT NULL
		SET @Qry += ' ORDER BY ' + @SortField + ' ' + UPPER(@SortOrder);
    ELSE
		SET @Qry += ' ORDER BY p.PayeeId DESC';

    EXEC (@Qry);
END
GO
