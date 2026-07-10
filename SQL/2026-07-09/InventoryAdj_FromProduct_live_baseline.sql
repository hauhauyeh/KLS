
CREATE   PROCEDURE [dbo].[InventoryAdj_FromProduct]
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

    -- Product-origin adjustments default to the normal before-receiving timing
    -- unless the caller explicitly chooses the closing/after-receiving path.
    IF @ResolvedOpenClose NOT IN ('Before Receiving', 'After Receiving')
    BEGIN
        SET @ResolvedOpenClose = 'Before Receiving';
    END;

    -- When price is being adjusted, this quick-create path should use
    -- the combined quantity/price adjustment type.
    IF @NewQty = 0 OR @NewPrice IS NOT NULL
    BEGIN
        SET @AdjType = 'B';
    END;

    -- Qty-only reset from the product dialog still needs to zero out cost.
    -- The UI no longer exposes price editing here, so a zero quantity means
    -- "reset inventory and reset average cost" unless another caller
    -- explicitly passes a replacement price.
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

    -- The qty-adjust dialog now passes the chosen timing directly.
    EXEC dbo.InventoryAdj_Insert
        @AdjId = 0,
        @AdjDate = @AdjDate,
        @AdjType = @AdjType,
        @OpenClose = @ResolvedOpenClose,
        @Notes = NULL,
        @EmpId = @EmpId,
        @NewAdjId = @NewAdjId OUTPUT;
END

