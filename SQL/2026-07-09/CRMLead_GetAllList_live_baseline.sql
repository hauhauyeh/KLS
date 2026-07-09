-- ============================================================
-- LIVE BASELINE (pre-2026-07-09) of dbo.CRMLead_GetAllList
-- The definition BEFORE sales-role row isolation was added.
-- Rollback: run this file to restore the prior definition.
-- ============================================================
USE [KLS-2026]
GO

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
    @TotalCount     INT           = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @IsCount = 1
    BEGIN
        SELECT @TotalCount = COUNT(*)
        FROM [CRMLead] L
        WHERE (@Search IS NULL OR L.LeadName LIKE '%' + @Search + '%' OR L.ContactPerson LIKE '%' + @Search + '%' OR L.Phone LIKE '%' + @Search + '%')
          AND (@Stage IS NULL OR L.Stage = @Stage)
          AND (@SalesRepId IS NULL OR L.SalesRepId = @SalesRepId)
          AND (@Id IS NULL OR L.LeadId = @Id);
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
