
CREATE   PROCEDURE [dbo].[Fn_Calc_RetailPrice]   -- EXEC: DECLARE @rp DECIMAL(18,2); EXEC dbo.Fn_Calc_RetailPrice @P1=100,@FactorToBase=1,@RetailProfitPercent=0.4,@RetailPrice=@rp OUTPUT,@MultipleToBase=1; SELECT @rp;

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

