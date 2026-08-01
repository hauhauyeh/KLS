SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- Employee_GetAllList  -  LIVE BASELINE captured 2026-08-01
-- Rollback reference for the hidden-super-admin change (IsSystemAccount filter).
-- Body is the live definition byte-for-byte; only CREATE was widened to
-- CREATE OR ALTER so this file is runnable as a rollback.
-- ============================================================


-- =============================================
-- Author:      <Author,,Name>
-- Create date: <Create Date,,>
-- Description: Get list of employees with search, status filter, and sorting
-- =============================================
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
        p.PayeeType = ''E''';

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
