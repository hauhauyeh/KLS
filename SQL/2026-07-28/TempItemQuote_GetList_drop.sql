-- R3A old temp ItemQuote SQL cleanup draft.
-- Object: dbo.TempItemQuote_GetList
-- Reason: R2A/R2B removed the only app-code caller.
-- Deploy only after explicit Howard approval.

SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.TempItemQuote_GetList', N'P') IS NOT NULL
BEGIN
    IF EXISTS (
        SELECT 1
        FROM sys.sql_expression_dependencies
        WHERE referenced_id = OBJECT_ID(N'dbo.TempItemQuote_GetList', N'P')
    )
        THROW 51001, 'Cannot drop dbo.TempItemQuote_GetList: SQL dependencies still reference it.', 1;

    DROP PROCEDURE dbo.TempItemQuote_GetList;
END
