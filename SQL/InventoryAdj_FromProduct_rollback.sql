SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[InventoryAdj_FromProduct]
    @AdjDate DATE,
    @ItemId INT,
    @NewQty DECIMAL(18,2),
    @NewPrice DECIMAL(18,2),
    @EmpId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AdjType NVARCHAR(50) = 'Q';
    DECLARE @NewAdjId INT;

    IF @NewQty = 0 OR @NewPrice IS NOT NULL
    BEGIN
        SET @AdjType = 'B';
    END;

    IF @NewQty = 0 AND @NewPrice IS NULL
    BEGIN
        SET @NewPrice = 0;
    END;

    DELETE FROM dbo.TempInventoryAdj
    WHERE EmpId = @EmpId;

    INSERT INTO dbo.TempInventoryAdj (
        EmpId,
        AdjId,
        ItemId,
        NewQty,
        NewPrice
    )
    VALUES (
        @EmpId,
        0,
        @ItemId,
        @NewQty,
        @NewPrice
    );

    EXEC dbo.InventoryAdj_Insert 0, @AdjDate, @AdjType, NULL, @EmpId, @NewAdjId OUTPUT;
END
GO
