USE [KLS-2026]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- CRMActivity_GetByEntity
-- 2026-07-21 (CRM Phase 3): customer mode merges pre-conversion
--   lead history — when @PayeeId is passed, rows of any lead with
--   ConvertedPayeeId = @PayeeId are included.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[CRMActivity_GetByEntity]
    @PayeeId    INT = NULL,
    @LeadId     INT = NULL,
    @Pageno     INT = 1,
    @Pagesize   INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        A.ActivityId,
        A.PayeeId,
        A.LeadId,
        A.ActivityType,
        A.Subject,
        A.[Description],
        A.ActivityDate,
        A.Duration,
        A.Outcome,
        P.PayeeName AS SalesRepName,
        A.CreatedAt
    FROM CRMActivity A
    LEFT JOIN Payee P ON A.SalesRepId = P.PayeeId
    WHERE (@PayeeId IS NOT NULL AND (
              A.PayeeId = @PayeeId
              OR A.LeadId IN (SELECT LeadId FROM CRMLead WHERE ConvertedPayeeId = @PayeeId)))
       OR (@LeadId IS NOT NULL AND A.LeadId = @LeadId)
    ORDER BY A.ActivityDate DESC
    OFFSET (@Pageno - 1) * @Pagesize ROWS
    FETCH NEXT @Pagesize ROWS ONLY;
END
GO
