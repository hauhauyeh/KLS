USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- CRMLead_GetAllList
-- 2026-07-09: sales-role row isolation (matches Customer_GetAllList).
--   New @EmpId param; derive @IsSalesRole from SystemUser/SystemRole;
--   sales roles only see their own rows, admins see all.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[CRMLead_GetAllList]
    @Pageno         INT = 1,
    @Pagesize       INT = 50,
    @Search         NVARCHAR(100) = NULL,
    @SortField      NVARCHAR(50)  = NULL,
    @SortOrder      NVARCHAR(4)   = NULL,
    @Stage          NVARCHAR(50)  = NULL,
    @SalesRepId     INT           = NULL,
    @Id             INT           = NULL,
    @IsCount        BIT           = 0,
    @TotalCount     INT           = 0 OUTPUT,
    @EmpId          INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- 2026-07-09: sales-role isolation. Derive the caller's role from
    -- SystemUser/SystemRole (same idiom as Customer_GetAllList). Sales
    -- roles are restricted to their own leads (SalesRepId = @EmpId).
    DECLARE @IsSalesRole BIT = 0;
    SELECT @IsSalesRole = sr.IsSalesRole
      FROM SystemUser su
      INNER JOIN SystemRole sr ON su.SystemRoleId = sr.SystemRoleId
      WHERE su.PayeeId = @EmpId;

    IF @IsCount = 1
    BEGIN
        SELECT @TotalCount = COUNT(*)
        FROM [CRMLead] L
        WHERE (@Search IS NULL OR L.LeadName LIKE '%' + @Search + '%' OR L.ContactPerson LIKE '%' + @Search + '%' OR L.Phone LIKE '%' + @Search + '%')
          AND (@Stage IS NULL OR L.Stage = @Stage)
          AND (@SalesRepId IS NULL OR L.SalesRepId = @SalesRepId)
          AND (@Id IS NULL OR L.LeadId = @Id)
          AND (@IsSalesRole = 0 OR L.SalesRepId = @EmpId);
        RETURN;
    END

    SELECT
        L.LeadId,
        L.LeadName,
        L.ContactPerson,
        L.Phone,
        L.Email,
        L.Stage,
        L.Source,
        P.PayeeName AS SalesRepName,
        L.EstimatedValue,
        (SELECT MIN(F.DueDate) FROM CRMFollowUp F WHERE F.LeadId = L.LeadId AND F.Status = 'Pending') AS NextFollowUpDate,
        L.ConvertedPayeeId,
        L.CreatedAt
    FROM [CRMLead] L
    LEFT JOIN [Payee] P ON L.SalesRepId = P.PayeeId
    WHERE (@Search IS NULL OR L.LeadName LIKE '%' + @Search + '%' OR L.ContactPerson LIKE '%' + @Search + '%' OR L.Phone LIKE '%' + @Search + '%')
      AND (@Stage IS NULL OR L.Stage = @Stage)
      AND (@SalesRepId IS NULL OR L.SalesRepId = @SalesRepId)
      AND (@Id IS NULL OR L.LeadId = @Id)
      AND (@IsSalesRole = 0 OR L.SalesRepId = @EmpId)
    ORDER BY
        CASE WHEN @SortField = 'LeadName' AND @SortOrder = 'asc' THEN L.LeadName END ASC,
        CASE WHEN @SortField = 'LeadName' AND @SortOrder = 'desc' THEN L.LeadName END DESC,
        CASE WHEN @SortField = 'Stage' AND @SortOrder = 'asc' THEN L.Stage END ASC,
        CASE WHEN @SortField = 'Stage' AND @SortOrder = 'desc' THEN L.Stage END DESC,
        CASE WHEN @SortField = 'CreatedAt' AND @SortOrder = 'asc' THEN L.CreatedAt END ASC,
        CASE WHEN @SortField = 'EstimatedValue' AND @SortOrder = 'asc' THEN L.EstimatedValue END ASC,
        CASE WHEN @SortField = 'EstimatedValue' AND @SortOrder = 'desc' THEN L.EstimatedValue END DESC,
        L.CreatedAt DESC
    OFFSET (@Pageno - 1) * @Pagesize ROWS
    FETCH NEXT @Pagesize ROWS ONLY;
END
GO
