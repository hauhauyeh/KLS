-- ============================================================
-- LIVE BASELINE (pre-2026-07-09) of dbo.CRMFollowUp_GetAllList
-- The definition BEFORE sales-role row isolation was added.
-- Rollback: run this file to restore the prior definition.
-- ============================================================
USE [KLS-2026]
GO

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
    @TotalCount     INT           = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

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
          AND (@EndDate IS NULL OR F.DueDate <= @EndDate);
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
