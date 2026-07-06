-- =============================================================================
-- Fn_Calc_RetailPrice -- deploy (CREATE OR ALTER). Working file per SP workflow.
-- 2026-07-06 (price phase, vertical 1): thread combine-up numerator into the retail-price
--   calc. Price scales INVERSE to qty -> a non-base unit's retail = base * MultipleToBase
--   / FactorToBase. New @MultipleToBase param is DEFAULTED (= 1) and placed LAST (after the
--   OUTPUT param) so the sole caller (Item_CalcRetailPriceAndProfit, a positional 4-arg EXEC)
--   still works at identity until it's threaded next -- backward-compatible bottom-up rollout.
--   Rollout guard: normalize @Mult = ISNULL(NULLIF(@MultipleToBase,0),1) (NULL/0 -> 1) so a
--   missed/old caller can't NULL a price. Identity for all production data (every ItemUnit is
--   Mult=1: (@P1/(1-profit)) * 1 / factor == old). Only CHIFT (Mult=10) computes combine-up.
-- Baseline: KLS/SQL/2026-07-06/Fn_Calc_RetailPrice_live_baseline.sql
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Fn_Calc_RetailPrice]   -- EXEC: DECLARE @rp DECIMAL(18,2); EXEC dbo.Fn_Calc_RetailPrice @P1=100,@FactorToBase=1,@RetailProfitPercent=0.4,@RetailPrice=@rp OUTPUT,@MultipleToBase=1; SELECT @rp;

   @P1 DECIMAL(18,2),
   @FactorToBase DECIMAL(18,2),
   @RetailProfitPercent DECIMAL(18,4),
   @RetailPrice DECIMAL(18,2) OUTPUT,
   @MultipleToBase INT = 1   -- 2026-07-06: combine-up numerator; defaulted + last so old positional callers stay identity
AS
BEGIN

	SET NOCOUNT ON;

	-- 2026-07-06: rollout guard -- normalize NULL/0 -> 1 (see price-side phase plan).
	DECLARE @Mult INT = ISNULL(NULLIF(@MultipleToBase, 0), 1);

	IF (@FactorToBase = 0 OR @FactorToBase IS NULL)
		SET @FactorToBase = 1

	IF @RetailProfitPercent IS NULL
		SELECT @RetailProfitPercent=SettingValue FROM SystemSetting WHERE SettingKey='ITEM_DEFAULT_RETAILPROFIT'

	-- 2026-07-06: threaded combine-up numerator (* @Mult). Old (Mult=1 identity):
	-- SET @RetailPrice = (@P1/(1-@RetailProfitPercent))/@FactorToBase
	SET @RetailPrice = (@P1/(1-@RetailProfitPercent)) * @Mult / @FactorToBase

	--New Formula
	--SET @RetailPrice = (@P1 / @FactorToBase) / (1 - @RetailProfitPercent)

	EXEC Fn_PriceRoundUp @RetailPrice,@RetailPrice OUTPUT

	SET @RetailPrice = ISNULL(@RetailPrice,0)

	RETURN
END
