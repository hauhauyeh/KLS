SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER TRIGGER [dbo].[TRG_Update_Sales]
ON dbo.Sales
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* Recompute LoadRoute only for rows where inputs changed */
    IF UPDATE(ShipRoute) OR UPDATE(RouteOrder) OR UPDATE(IsLoadSeparate)
    BEGIN
        UPDATE s
        SET s.LoadRoute = dbo.Fn_Calc_EffectiveLoadRoute(i.ShipRoute, i.RouteOrder, i.IsLoadSeparate)
        FROM dbo.Sales s
        INNER JOIN inserted i
            ON i.SalesId = s.SalesId;
    END
END
GO
