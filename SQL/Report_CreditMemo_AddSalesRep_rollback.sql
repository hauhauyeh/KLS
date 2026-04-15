SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.Report_CreditMemo_prev', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.Report_CreditMemo;
    EXEC sp_rename 'dbo.Report_CreditMemo_prev', 'Report_CreditMemo';
END
GO
