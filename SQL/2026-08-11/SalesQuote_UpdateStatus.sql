SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- SalesQuote_UpdateStatus
-- 2026-08-11: harden manual status transitions.
--   Manual users own Draft/Sent/Accepted/Rejected transitions.
--   Scheduler owns Expired. Conversion SPs own Converted.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[SalesQuote_UpdateStatus]
    @SalesQuoteId   INT,
    @StatusId       INT,
    @EmpId          INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentStatusId INT;
    DECLARE @SalesId INT;

    SELECT
        @CurrentStatusId = StatusId,
        @SalesId = SalesId
    FROM SalesQuote
    WHERE SalesQuoteId = @SalesQuoteId;

    IF @CurrentStatusId IS NULL
    BEGIN
        RAISERROR('Sales quote not found.', 16, 1);
        RETURN;
    END

    IF @CurrentStatusId = 5 OR @SalesId IS NOT NULL
    BEGIN
        RAISERROR('Converted sales quote status cannot be changed manually.', 16, 1);
        RETURN;
    END

    IF @CurrentStatusId IN (3, 4)
    BEGIN
        RAISERROR('Rejected or expired sales quote status cannot be changed manually.', 16, 1);
        RETURN;
    END

    IF @StatusId IN (4, 5)
    BEGIN
        RAISERROR('Expired and Converted statuses are system-managed.', 16, 1);
        RETURN;
    END

    IF NOT
    (
        (@StatusId = 0 AND @CurrentStatusId = 2)
        OR (@StatusId = 1 AND @CurrentStatusId IN (0, 2))
        OR (@StatusId IN (2, 3) AND @CurrentStatusId IN (0, 1))
    )
    BEGIN
        RAISERROR('Invalid sales quote status transition.', 16, 1);
        RETURN;
    END

    UPDATE SalesQuote
    SET
        StatusId = @StatusId,
        Updateby = @EmpId,
        UpdatedAt = GETUTCDATE()
    WHERE SalesQuoteId = @SalesQuoteId;
END
GO
