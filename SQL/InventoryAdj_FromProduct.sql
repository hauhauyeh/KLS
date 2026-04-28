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

    -- When price is being adjusted, this quick-create path should use
    -- the combined quantity/price adjustment type.
    IF @NewQty = 0 OR @NewPrice IS NOT NULL
    BEGIN
        SET @AdjType = 'B';
    END;

    IF @NewQty = 0 AND @NewPrice IS NULL
    BEGIN
        SET @NewPrice = 0;
    END;

    -- This path creates a fresh adjustment from the product screen,
    -- so clear any previous temp rows for the current user first.
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

    -- Product-origin adjustments should continue to post as the normal
    -- "Before Receiving" timing unless the user opens the full adjustment
    -- screen and changes the timing explicitly.
    EXEC dbo.InventoryAdj_Insert
        @AdjId = 0,
        @AdjDate = @AdjDate,
        @AdjType = @AdjType,
        @OpenClose = 'Before Receiving',
        @Notes = NULL,
        @EmpId = @EmpId,
        @NewAdjId = @NewAdjId OUTPUT;
END
GO
