IF OBJECT_ID('dbo.Fn_Calc_NextShipDate', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE [dbo].[Fn_Calc_NextShipDate];
END
GO

IF OBJECT_ID('dbo.Fn_Calc_NextShipDate_prev', 'P') IS NOT NULL
BEGIN
    EXEC sp_rename 'dbo.Fn_Calc_NextShipDate_prev', 'Fn_Calc_NextShipDate';
END
GO

IF OBJECT_ID('dbo.DeliverSchedule', 'U') IS NOT NULL
BEGIN
    DROP TABLE [dbo].[DeliverSchedule];
END
GO
