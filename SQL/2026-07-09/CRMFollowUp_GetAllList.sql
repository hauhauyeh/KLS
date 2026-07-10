USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- CRMFollowUp_GetAllList
-- 2026-07-09: sales-role row isolation (matches Customer_GetAllList).
--   New @EmpId param; derive @IsSalesRole from SystemUser/SystemRole;
--   sales roles only see their own rows, admins see all.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[CRMFollowUp_GetAllList]
    @Pageno         INT = 1,
    @Pagesize       INT = 50,
    @Search         NVARCHAR(100) = NULL,
    @SortField      NVARCHAR(50)  = NULL,
    @SortOrder      NVARCHAR(4)   = NULL,
    @AssignedTo     INT           = NULL,
    @Status         NVARCHAR(20)  = NULL,
    @Priority       NVARCHAR(10)  = NULL,
    @StartDate      DATE          = NULL,
    @EndDate        DATE          = NULL,
    @IsCount        BIT           = 0,
    @TotalCount     INT           = 0 OUTPUT,
    @EmpId          INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

    -- 2026-07-09: sales-role isolation. Derive the caller's role from
    -- SystemUser/SystemRole (same idiom as Customer_GetAllList). Sales
    -- roles are restricted to their own follow-ups (AssignedTo = @EmpId).
    DECLARE @IsSalesRole BIT = 0;
    SELECT @IsSalesRole = sr.IsSalesRole
      FROM SystemUser su
      INNER JOIN SystemRole sr ON su.SystemRoleId = sr.SystemRoleId
      WHERE su.PayeeId = @EmpId;

    IF @IsCount = 1
    BEGIN
        SELECT @TotalCount = COUNT(*)
        FROM CRMFollowUp F
        LEFT JOIN Payee C ON F.PayeeId = C.PayeeId
        LEFT JOIN CRMLead L ON F.LeadId = L.LeadId
        WHERE (@Search IS NULL OR F.Subject LIKE '%' + @Search + '%' OR C.PayeeName LIKE '%' + @Search + '%' OR L.LeadName LIKE '%' + @Search + '%')
          AND (@AssignedTo IS NULL OR F.AssignedTo = @AssignedTo)
          AND (@Status IS NULL OR F.Status = @Status)
          AND (@Priority IS NULL OR F.Priority = @Priority)
          AND (@StartDate IS NULL OR F.DueDate >= @StartDate)
          AND (@EndDate IS NULL OR F.DueDate <= @EndDate)
          AND (@IsSalesRole = 0 OR F.AssignedTo = @EmpId);
        RETURN;
    END

    SELECT
        F.FollowUpId,
        F.PayeeId,
        F.LeadId,
        F.Subject,
        F.DueDate,
        F.DueTime,
        F.Priority,
        F.Status,
        CASE
            WHEN F.Status = 'Pending' AND F.DueDate < @Today THEN 'Overdue'
            WHEN F.Status = 'Pending' AND F.DueDate = @Today THEN 'Today'
            WHEN F.Status = 'Pending' AND F.DueDate > @Today THEN 'Upcoming'
            ELSE F.Status
        END AS [Group],
        C.PayeeName AS CustomerName,
        L.LeadName,
        PA.PayeeName AS AssignedToName,
        F.AssignedTo,
        F.CompletedAt,
        F.CreatedAt
    FROM CRMFollowUp F
    LEFT JOIN Payee C ON F.PayeeId = C.PayeeId
    LEFT JOIN CRMLead L ON F.LeadId = L.LeadId
    LEFT JOIN Payee PA ON F.AssignedTo = PA.PayeeId
    WHERE (@Search IS NULL OR F.Subject LIKE '%' + @Search + '%' OR C.PayeeName LIKE '%' + @Search + '%' OR L.LeadName LIKE '%' + @Search + '%')
      AND (@AssignedTo IS NULL OR F.AssignedTo = @AssignedTo)
      AND (@Status IS NULL OR F.Status = @Status)
      AND (@Priority IS NULL OR F.Priority = @Priority)
      AND (@StartDate IS NULL OR F.DueDate >= @StartDate)
      AND (@EndDate IS NULL OR F.DueDate <= @EndDate)
      AND (@IsSalesRole = 0 OR F.AssignedTo = @EmpId)
    ORDER BY
        CASE
            WHEN F.Status = 'Pending' AND F.DueDate < @Today THEN 0
            WHEN F.Status = 'Pending' AND F.DueDate = @Today THEN 1
            WHEN F.Status = 'Pending' AND F.DueDate > @Today THEN 2
            ELSE 3
        END,
        F.DueDate ASC
    OFFSET (@Pageno - 1) * @Pagesize ROWS
    FETCH NEXT @Pagesize ROWS ONLY;
END
GO
