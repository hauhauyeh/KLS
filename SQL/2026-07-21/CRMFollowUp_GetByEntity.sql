USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- CRMFollowUp_GetByEntity
-- 2026-07-21 (CRM Phase 3): customer mode merges pre-conversion
--   lead history — when @PayeeId is passed, rows of any lead with
--   ConvertedPayeeId = @PayeeId are included.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[CRMFollowUp_GetByEntity]
    @PayeeId    INT = NULL,
    @LeadId     INT = NULL,
    @Pageno     INT = 1,
    @Pagesize   INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CAST(GETDATE() AS DATE);

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
    WHERE (@PayeeId IS NOT NULL AND (
              F.PayeeId = @PayeeId
              OR F.LeadId IN (SELECT LeadId FROM CRMLead WHERE ConvertedPayeeId = @PayeeId)))
       OR (@LeadId IS NOT NULL AND F.LeadId = @LeadId)
    ORDER BY
        CASE
            WHEN F.Status = 'Pending' AND F.DueDate < @Today THEN 0
            WHEN F.Status = 'Pending' AND F.DueDate = @Today THEN 1
            WHEN F.Status = 'Pending' AND F.DueDate > @Today THEN 2
            ELSE 3
        END,
        CASE WHEN F.Status = 'Pending' THEN F.DueDate END ASC,
        F.DueDate DESC
    OFFSET (@Pageno - 1) * @Pagesize ROWS
    FETCH NEXT @Pagesize ROWS ONLY;
END
GO
