SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.fn_TxDetailEnriched', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_TxDetailEnriched;
GO
