SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- Payee_SearchByTerm  -  LIVE BASELINE captured 2026-08-01
-- Rollback reference for the hidden-super-admin change (IsSystemAccount filter).
-- Body is the live definition byte-for-byte; only CREATE was widened to
-- CREATE OR ALTER so this file is runnable as a rollback.
-- ============================================================

CREATE OR ALTER PROCEDURE [dbo].[Payee_SearchByTerm]
    @SearchTerm NVARCHAR(100),
    @IsActiveOnly   BIT
AS
BEGIN
    SET NOCOUNT ON;

    -- Trim and handle NULL
    DECLARE @term NVARCHAR(100) = LTRIM(RTRIM(ISNULL(@SearchTerm, N'')));
    DECLARE @contains NVARCHAR(200) = N'%' + @term + N'%';
    DECLARE @starts   NVARCHAR(200) = @term + N'%';

    SELECT
        PayeeId,
        PayeeType,
        PayeeName,
        IsClosed
    FROM Payee
    WHERE
        (@IsActiveOnly = 0 OR IsClosed = 0)
        AND (
               PayeeName LIKE @contains
            OR Phone1    LIKE @contains
            OR Phone2    LIKE @contains
            OR Phone3    LIKE @contains
            OR Phone4    LIKE @contains
            OR CONVERT(NVARCHAR(20), PayeeId) LIKE @contains
        )
    ORDER BY
        CASE
            WHEN PayeeName LIKE @starts   THEN 0
            WHEN PayeeName LIKE @contains THEN 1
            ELSE 2
        END,
        PayeeName;
END

GO
