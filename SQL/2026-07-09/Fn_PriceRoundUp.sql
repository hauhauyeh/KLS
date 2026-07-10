
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B-Phase2-Slice1-Fn_PriceRoundUp: Decision-A round-up bypass (setting-gated).
--   Reads PRICE_DISPLAY_DECIMALS (guard: missing/0/2/invalid -> 2, =4 -> 4).
--   setting=2: ROUND(@Price,2) + psychological .99/.29 round-up (BYTE-IDENTICAL to prior behavior).
--   setting=4: ROUND(@Price,4), bypass the .99/.29 endings (2dp-only) -> return clean 4dp price.
--   (Section B Phase-1 already widened the @Price/@RoundedPrice types to 18,4.)
CREATE OR ALTER PROCEDURE [dbo].[Fn_PriceRoundUp]

	-- 4dp widen: was DECIMAL(18,2)
	@Price DECIMAL(18,4),
	-- 4dp widen: was DECIMAL(18,2)
	@RoundedPrice DECIMAL(18,4) OUTPUT
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @PriceINT INT;
	DECLARE @Difference DECIMAL(18,2);
	DECLARE @IsPriceRoundup BIT
	-- 2026-07-09 Decision-A: read the active price-decimals mode (guard missing/0/2/invalid -> 2, =4 -> 4)
	DECLARE @PriceDecimals INT
	SELECT @PriceDecimals = TRY_CAST(SettingValue AS INT) FROM SystemSetting WHERE SettingKey='PRICE_DISPLAY_DECIMALS'
	SET @PriceDecimals = CASE WHEN @PriceDecimals = 4 THEN 4 ELSE 2 END

	-- 2026-07-09 Decision-A: round to the active mode. Old: SET @Price = ROUND(@Price,2)
	SET @Price = ROUND(@Price,@PriceDecimals)

	SET @RoundedPrice=@Price

	-- 2026-07-09 Decision-A: the .99/.29 psychological round-up is 2dp-only; bypass it in 4dp mode
	-- (return the clean 4dp price). setting=2 falls through to the unchanged round-up logic below.
	IF @PriceDecimals = 4
		RETURN

	SELECT @IsPriceRoundup=SettingValue FROM SystemSetting WHERE SettingKey='ITEM_PRICE_ROUNDUP'

	IF @IsPriceRoundup=0
		RETURN

	SELECT @PriceINT = FLOOR(@Price)

	SET @Difference = CAST(((@Price*100) - (@PriceINT*100)) AS INT)

	--for kls and abc
	IF (@Difference>=0 AND @Difference<=5)
		SET @RoundedPrice = (@PriceINT-1) + 0.99
	ELSE IF (@Difference>=6 AND @Difference<=24)
		SET @RoundedPrice = @PriceINT + 0.29
	ELSE IF (@Difference>=25 AND @Difference<=49)
		SET @RoundedPrice = @PriceINT + 0.49
	ELSE IF (@Difference>=50 AND @Difference<=74)
		SET @RoundedPrice = @PriceINT + 0.79
	ELSE IF (@Difference>=75 AND @Difference<=99)
		SET @RoundedPrice = @PriceINT + 0.99
	ELSE
		SET @RoundedPrice = @PriceINT

	--for mgp
	--IF (@Difference>=0 AND @Difference<=5)
	--	SET @RoundedPrice = (@PriceINT-1) + 0.95
	--ELSE IF (@Difference>=6 AND @Difference<=24)
	--	SET @RoundedPrice = @PriceINT + 0.25
	--ELSE IF (@Difference>=25 AND @Difference<=49)
	--	SET @RoundedPrice = @PriceINT + 0.5
	--ELSE IF (@Difference>=50 AND @Difference<=74)
	--	SET @RoundedPrice = @PriceINT + 0.75
	--ELSE IF (@Difference>=75 AND @Difference<=99)
	--	SET @RoundedPrice = @PriceINT + 0.95
	--ELSE
	--	SET @RoundedPrice = @PriceINT

	RETURN

END
GO



