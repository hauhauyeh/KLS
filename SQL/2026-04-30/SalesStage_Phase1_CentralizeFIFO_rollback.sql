SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Sales_UpdateStage]
    @SalesId INT,
    @StageId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentStageId INT;

    SELECT @CurrentStageId = StageId
    FROM dbo.Sales
    WHERE SalesId = @SalesId;

    UPDATE dbo.Sales
    SET StageId = @StageId,
        UpdatedAt = GETUTCDATE()
    WHERE SalesId = @SalesId;

    IF @CurrentStageId = 0
    BEGIN
        EXEC dbo.FIFO_Single_Allocation @SalesId;
    END

    SELECT *
    FROM dbo.SalesStage
    WHERE StageId = @StageId;
END
GO

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

    /* 1) Recompute LoadRoute only for rows where inputs changed */
    IF UPDATE(ShipRoute) OR UPDATE(RouteOrder) OR UPDATE(IsLoadSeparate)
    BEGIN
        UPDATE s
        SET s.LoadRoute = dbo.Fn_Calc_EffectiveLoadRoute(i.ShipRoute, i.RouteOrder, i.IsLoadSeparate)
        FROM dbo.Sales s
        INNER JOIN inserted i
            ON i.SalesId = s.SalesId;
    END

    /* 2) Clear FIFO fields only for rows where StageId changed 2 -> 0 */
    IF UPDATE(StageId)
    BEGIN
        UPDATE sd
        SET sd.FIFOHistory = NULL,
            sd.FIFOCost    = NULL
        FROM dbo.SalesDetail sd
        INNER JOIN inserted i
            ON i.SalesId = sd.SalesId
        INNER JOIN deleted d
            ON d.SalesId = i.SalesId
        WHERE d.StageId = 2
          AND i.StageId = 0
          AND (sd.FIFOHistory IS NOT NULL OR sd.FIFOCost IS NOT NULL);
    END
END
GO
