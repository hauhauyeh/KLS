USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- CRM_MyDay (new, CRM Phase 5)
-- Personal work queue: pending follow-ups assigned to @EmpId due
-- within 7 days of @Today, bucketed Overdue/Today/Upcoming, plus
-- rows completed by @EmpId today (Bucket = 'Completed', used by
-- the frontend for the Completed Today stat only).
-- @Today is the USER-LOCAL date and @TodayStartUtc/@TodayEndUtc the
-- UTC window of that local day — computed by the API from the JWT
-- timezone claim. CompletedAt is stored UTC; do not CAST it to date.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[CRM_MyDay]
    @EmpId          INT,
    @Today          DATE,
    @TodayStartUtc  DATETIME,
    @TodayEndUtc    DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Horizon DATE = DATEADD(DAY, 7, @Today);

    SELECT *
    FROM (
        SELECT
            F.FollowUpId,
            F.LeadId,
            F.PayeeId,
            L.ConvertedPayeeId,
            COALESCE(C.PayeeName, CP.PayeeName, L.LeadName) AS DisplayName,
            F.Subject,
            F.Priority,
            F.DueDate,
            F.DueTime,
            CASE
                WHEN F.DueDate < @Today THEN 'Overdue'
                WHEN F.DueDate = @Today THEN 'Today'
                ELSE 'Upcoming'
            END AS Bucket
        FROM CRMFollowUp F
        LEFT JOIN Payee C ON F.PayeeId = C.PayeeId
        LEFT JOIN CRMLead L ON F.LeadId = L.LeadId
        LEFT JOIN Payee CP ON L.ConvertedPayeeId = CP.PayeeId
        WHERE F.AssignedTo = @EmpId
          AND F.Status = 'Pending'
          AND F.DueDate <= @Horizon

        UNION ALL

        SELECT
            F.FollowUpId,
            F.LeadId,
            F.PayeeId,
            L.ConvertedPayeeId,
            COALESCE(C.PayeeName, CP.PayeeName, L.LeadName),
            F.Subject,
            F.Priority,
            F.DueDate,
            F.DueTime,
            'Completed'
        FROM CRMFollowUp F
        LEFT JOIN Payee C ON F.PayeeId = C.PayeeId
        LEFT JOIN CRMLead L ON F.LeadId = L.LeadId
        LEFT JOIN Payee CP ON L.ConvertedPayeeId = CP.PayeeId
        WHERE F.CompletedBy = @EmpId
          AND F.Status = 'Completed'
          AND F.CompletedAt >= @TodayStartUtc
          AND F.CompletedAt < @TodayEndUtc
    ) M
    ORDER BY
        CASE M.Bucket
            WHEN 'Overdue' THEN 0
            WHEN 'Today' THEN 1
            WHEN 'Upcoming' THEN 2
            ELSE 3
        END,
        M.DueDate ASC,
        M.DueTime ASC;
END
GO
