-- =============================================================================
-- Item_UpdateBaseP1 -- LIVE BASELINE captured 2026-07-06 (frozen rollback ref).
-- Sole rollback artifact. Restores BOTH the pre-MultipleToBase form AND the
-- pre-existing stale-var loop bug (documented; 2-item impact). Do not edit.
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Item_UpdateBaseP1]
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[Item_UpdateBaseP1]
	
	@ItemUnitId INT,
	@BaseP1 DECIMAL(18,2)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @ItemId INT

	SELECT @ItemId=ItemId FROM ItemUnit WHERE ItemUnitId=@ItemUnitId

	UPDATE ItemUnit SET P1=@BaseP1 WHERE ItemUnitId=@ItemUnitId

	SELECT * FROM ItemUnit WHERE ItemUnitId<>@ItemUnitId AND ItemId=@ItemId

	-- Temp table of other (non-base) units for same item
    CREATE TABLE #OtherUnits(
        RowNo INT IDENTITY(1,1) PRIMARY KEY,
        ItemUnitId INT NOT NULL,
		FactorToBase DECIMAL(18,6) NOT NULL
    );

	INSERT INTO #OtherUnits(ItemUnitId,FactorToBase)
    SELECT ItemUnitId,FactorToBase FROM ItemUnit
    WHERE ItemId = @ItemId
      AND ItemUnitId <> @ItemUnitId
      AND IsBaseUnit = 0;

	DECLARE @RowNum INT = 1;
	DECLARE @MaxRows INT;
	DECLARE @OtherItemUnitId INT;
	DECLARE @FactorToBase DECIMAL(18,6);
	DECLARE @RetailPrice DECIMAL(18,2);
	DECLARE @RetailPercent DECIMAL(18,4);

	SELECT @MaxRows = COUNT(*) FROM #OtherUnits;

	WHILE @RowNum <= @MaxRows
	BEGIN
		SELECT @OtherItemUnitId = ItemUnitId,
		@FactorToBase = FactorToBase
		FROM #OtherUnits
        WHERE RowNo = @RowNum;

        EXEC dbo.Item_CalcRetailPriceAndProfit @BaseP1,@FactorToBase,@RetailPrice OUTPUT,@RetailPercent OUTPUT

		UPDATE ItemUnit SET P1=@RetailPrice WHERE ItemUnitId=@OtherItemUnitId

        SET @RowNum = @RowNum + 1;
	END
END
