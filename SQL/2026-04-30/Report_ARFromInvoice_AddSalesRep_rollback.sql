SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Report_ARFromInvoice];
GO

EXEC sp_rename 'Report_ARFromInvoice_prev', 'Report_ARFromInvoice';
GO
