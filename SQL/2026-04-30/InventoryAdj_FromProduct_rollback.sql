SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[InventoryAdj_FromProduct]
    @AdjDate DATE,
    @ItemId INT,
    @OpenClose NVARCHAR(50),
    @NewQty DECIMAL(18,2),
    @NewPrice DECIMAL(18,2),
    @EmpId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AdjType NVARCHAR(50) = 'Q';
    DECLARE @NewAdjId INT;
    DECLARE @ResolvedOpenClose NVARCHAR(50) = LTRIM(RTRIM(ISNULL(@OpenClose, '')));

    -- Rollback keeps the current request contract stable.
    -- If timing is missing or invalid, fall back to the normal before-receiving path.
    IF @ResolvedOpenClose NOT IN ('Before Receiving', 'After Receiving')
    BEGIN
        SET @ResolvedOpenClose = 'Before Receiving';
    END;

    IF @NewQty = 0 OR @NewPrice IS NOT NULL
    BEGIN
        SET @AdjType = 'B';
    END;

    -- Preserve the existing zero-qty reset rule.
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

    EXEC dbo.InventoryAdj_Insert
        @AdjId = 0,
        @AdjDate = @AdjDate,
        @AdjType = @AdjType,
        @OpenClose = @ResolvedOpenClose,
        @Notes = NULL,
        @EmpId = @EmpId,
        @NewAdjId = @NewAdjId OUTPUT;
END
GO
