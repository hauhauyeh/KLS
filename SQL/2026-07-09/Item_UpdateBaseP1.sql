
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B-Phase2-Slice4a-Item_UpdateBaseP1: widen the retail-calc chain to (18,4).
--   Widen @BaseP1 (entered base price, written to base P1) + @RetailPrice (per-unit result written to P1) -> (18,4)
--   so 4dp flows at setting=4. Inert at setting=2 (<=2dp data). The round-once + setting gate live in
--   Fn_Calc_RetailPrice (Slice-4a), which this reaches via Item_CalcRetailPriceAndProfit.
CREATE OR ALTER PROCEDURE [dbo].[Item_UpdateBaseP1]   -- EXEC dbo.Item_UpdateBaseP1 @ItemUnitId=1242, @BaseP1=125;

	@ItemUnitId INT,
	-- 4dp widen (entered base price): was DECIMAL(18,2)
	@BaseP1 DECIMAL(18,4)
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
		FactorToBase DECIMAL(18,6) NOT NULL,
		MultipleToBase INT NOT NULL   -- 2026-07-06: added -- combine-up numerator (from ItemUnit)
    );

	-- 2026-07-06: thread MultipleToBase into the load. Old:
	-- INSERT INTO #OtherUnits(ItemUnitId,FactorToBase)
	-- SELECT ItemUnitId,FactorToBase FROM ItemUnit
	INSERT INTO #OtherUnits(ItemUnitId,FactorToBase,MultipleToBase)
    SELECT ItemUnitId,FactorToBase,MultipleToBase FROM ItemUnit
    WHERE ItemId = @ItemId
      AND ItemUnitId <> @ItemUnitId
      AND IsBaseUnit = 0;

	DECLARE @RowNum INT = 1;
	DECLARE @MaxRows INT;
	DECLARE @OtherItemUnitId INT;
	DECLARE @FactorToBase DECIMAL(18,6);
	DECLARE @MultipleToBase INT;   -- 2026-07-06: added -- combine-up numerator
	-- 4dp widen (per-unit retail result written to P1): was DECIMAL(18,2)
	DECLARE @RetailPrice DECIMAL(18,4);
	DECLARE @RetailPercent DECIMAL(18,4);

	SELECT @MaxRows = COUNT(*) FROM #OtherUnits;

	WHILE @RowNum <= @MaxRows
	BEGIN
		-- 2026-07-06 BUG FIX (separate from the MultipleToBase threading): reset the INOUT scalars
		-- each iteration. @RetailPrice is INOUT into Item_CalcRetailPriceAndProfit; unreset, iter 2+
		-- carries the prior unit's price (>0) -> CASE 1 (reverse) fires instead of CASE 2 (forward),
		-- and the next unit is written the prior unit's P1. Affects items with 2+ non-base units.
		-- (CLAUDE.md: reset scalar vars each loop iteration.)
		SET @RetailPrice = NULL;
		SET @RetailPercent = NULL;

		-- 2026-07-06: thread @MultipleToBase into the var-load. Old:
		-- SELECT @OtherItemUnitId = ItemUnitId, @FactorToBase = FactorToBase FROM #OtherUnits WHERE RowNo = @RowNum;
		SELECT @OtherItemUnitId = ItemUnitId,
		@FactorToBase = FactorToBase,
		@MultipleToBase = MultipleToBase
		FROM #OtherUnits
        WHERE RowNo = @RowNum;

		-- 2026-07-06: pass @MultipleToBase (trailing arg; the calc SP normalizes it). Old:
		-- EXEC dbo.Item_CalcRetailPriceAndProfit @BaseP1,@FactorToBase,@RetailPrice OUTPUT,@RetailPercent OUTPUT
        EXEC dbo.Item_CalcRetailPriceAndProfit @BaseP1,@FactorToBase,@RetailPrice OUTPUT,@RetailPercent OUTPUT,@MultipleToBase

		UPDATE ItemUnit SET P1=@RetailPrice WHERE ItemUnitId=@OtherItemUnitId

        SET @RowNum = @RowNum + 1;
	END
END
GO
