SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-MARGINFIX-Item_UpdateBaseP1 (2026-07-09): base-P1 cascade now preserves EACH non-base unit's
--   OWN margin (ItemUnit.PricePercentToBase) instead of repricing every unit at the global
--   ITEM_DEFAULT_RETAILPROFIT. Matches item-add-edit onChangeP1 -> recalculateFromFactorAndPercent
--   (P1 = baseP1 / (1 - margin) * MultipleToBase / FactorToBase, margin = that unit's PricePercentToBase).
--   Units with NO stored margin (NULL) still fall back to ITEM_DEFAULT_RETAILPROFIT inside
--   Item_CalcRetailPriceAndProfit (prior behavior preserved for those rows only).
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
		MultipleToBase INT NOT NULL,   -- 2026-07-06: added -- combine-up numerator (from ItemUnit)
		PricePercentToBase DECIMAL(18,4) NULL   -- 2026-07-09 marginfix: per-unit margin (source col is DECIMAL(18,4) NULL)
    );

	-- 2026-07-06: thread MultipleToBase into the load. Old:
	-- INSERT INTO #OtherUnits(ItemUnitId,FactorToBase)
	-- SELECT ItemUnitId,FactorToBase FROM ItemUnit
	-- 2026-07-09 marginfix: also load PricePercentToBase (per-unit margin). Old (2026-07-06 line):
	-- INSERT INTO #OtherUnits(ItemUnitId,FactorToBase,MultipleToBase)
	-- SELECT ItemUnitId,FactorToBase,MultipleToBase FROM ItemUnit
	INSERT INTO #OtherUnits(ItemUnitId,FactorToBase,MultipleToBase,PricePercentToBase)
    SELECT ItemUnitId,FactorToBase,MultipleToBase,PricePercentToBase FROM ItemUnit
    WHERE ItemId = @ItemId
      AND ItemUnitId <> @ItemUnitId
      AND IsBaseUnit = 0;

	DECLARE @RowNum INT = 1;
	DECLARE @MaxRows INT;
	DECLARE @OtherItemUnitId INT;
	DECLARE @FactorToBase DECIMAL(18,6);
	DECLARE @MultipleToBase INT;   -- 2026-07-06: added -- combine-up numerator
	DECLARE @PricePercentToBase DECIMAL(18,4);   -- 2026-07-09 marginfix: this unit's stored margin
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
		-- 2026-07-09 marginfix: was `SET @RetailPercent = NULL;` (this reset made CASE 2 fall back to the
		-- global ITEM_DEFAULT_RETAILPROFIT for EVERY unit). @RetailPercent is now assigned from this unit's
		-- stored margin AFTER the row load below; here we just reset the per-unit margin var each iteration.
		SET @PricePercentToBase = NULL;

		-- 2026-07-06: thread @MultipleToBase into the var-load. Old:
		-- SELECT @OtherItemUnitId = ItemUnitId, @FactorToBase = FactorToBase FROM #OtherUnits WHERE RowNo = @RowNum;
		-- 2026-07-09 marginfix: also load @PricePercentToBase.
		SELECT @OtherItemUnitId = ItemUnitId,
		@FactorToBase = FactorToBase,
		@MultipleToBase = MultipleToBase,
		@PricePercentToBase = PricePercentToBase
		FROM #OtherUnits
        WHERE RowNo = @RowNum;

		-- 2026-07-09 marginfix: feed THIS unit's stored margin into the retail calc so each unit is
		-- repriced at its OWN current margin (matches item-add-edit). A NULL margin stays NULL here, and
		-- Item_CalcRetailPriceAndProfit falls back to ITEM_DEFAULT_RETAILPROFIT (unchanged for those rows).
		SET @RetailPercent = @PricePercentToBase;

		-- 2026-07-06: pass @MultipleToBase (trailing arg; the calc SP normalizes it). Old:
		-- EXEC dbo.Item_CalcRetailPriceAndProfit @BaseP1,@FactorToBase,@RetailPrice OUTPUT,@RetailPercent OUTPUT
        EXEC dbo.Item_CalcRetailPriceAndProfit @BaseP1,@FactorToBase,@RetailPrice OUTPUT,@RetailPercent OUTPUT,@MultipleToBase

		UPDATE ItemUnit SET P1=@RetailPrice WHERE ItemUnitId=@OtherItemUnitId

        SET @RowNum = @RowNum + 1;
	END
END
GO
