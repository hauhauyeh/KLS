
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B-Phase2-Slice4a-Fn_Calc_RetailPrice: Class-C retail-calc round-once restructure (setting-gated).
--   Read PRICE_DISPLAY_DECIMALS (guard missing/0/2/invalid -> 2, =4 -> 4) and round the retail formula ONCE to
--   @PriceDecimals (was an implicit 18,2 round on assignment). Widen @P1 + @RetailPrice OUTPUT -> (18,4) so 4dp
--   flows at setting=4. setting=2: byte-identical (ROUND(formula,2) == the old 18,2 assignment) + Fn_PriceRoundUp
--   (Slice-1) idempotent round + .99. setting=4: 4dp retail, Fn_PriceRoundUp bypasses .99. @FactorToBase (ratio) left.
CREATE OR ALTER PROCEDURE [dbo].[Fn_Calc_RetailPrice]   -- EXEC: DECLARE @rp DECIMAL(18,4); EXEC dbo.Fn_Calc_RetailPrice @P1=100,@FactorToBase=1,@RetailProfitPercent=0.4,@RetailPrice=@rp OUTPUT,@MultipleToBase=1; SELECT @rp;

   -- 4dp widen (entered base price): was DECIMAL(18,2)
   @P1 DECIMAL(18,4),
   @FactorToBase DECIMAL(18,2),
   @RetailProfitPercent DECIMAL(18,4),
   -- 4dp widen (retail price out): was DECIMAL(18,2)
   @RetailPrice DECIMAL(18,4) OUTPUT,
   @MultipleToBase INT = 1   -- 2026-07-06: combine-up numerator; defaulted + last so old positional callers stay identity
AS
BEGIN

	SET NOCOUNT ON;

	-- 2026-07-06: rollout guard -- normalize NULL/0 -> 1 (see price-side phase plan).
	DECLARE @Mult INT = ISNULL(NULLIF(@MultipleToBase, 0), 1);

	-- 2026-07-09 Slice-4a: read the active price-decimals mode (guard missing/0/2/invalid -> 2, =4 -> 4)
	DECLARE @PriceDecimals INT;
	SELECT @PriceDecimals = TRY_CAST(SettingValue AS INT) FROM dbo.SystemSetting WHERE SettingKey='PRICE_DISPLAY_DECIMALS';
	SET @PriceDecimals = CASE WHEN @PriceDecimals = 4 THEN 4 ELSE 2 END;

	IF (@FactorToBase = 0 OR @FactorToBase IS NULL)
		SET @FactorToBase = 1

	IF @RetailProfitPercent IS NULL
		SELECT @RetailProfitPercent=SettingValue FROM SystemSetting WHERE SettingKey='ITEM_DEFAULT_RETAILPROFIT'

	-- 2026-07-06: threaded combine-up numerator (* @Mult). Old (Mult=1 identity):
	-- SET @RetailPrice = (@P1/(1-@RetailProfitPercent))/@FactorToBase
	-- 2026-07-09 Slice-4a: round the formula ONCE to the active mode (was an implicit 18,2 round on assignment).
	-- was: SET @RetailPrice = (@P1/(1-@RetailProfitPercent)) * @Mult / @FactorToBase
	SET @RetailPrice = ROUND((@P1/(1-@RetailProfitPercent)) * @Mult / @FactorToBase, @PriceDecimals)

	--New Formula
	--SET @RetailPrice = (@P1 / @FactorToBase) / (1 - @RetailProfitPercent)

	EXEC Fn_PriceRoundUp @RetailPrice,@RetailPrice OUTPUT

	SET @RetailPrice = ISNULL(@RetailPrice,0)

	RETURN
END
GO
