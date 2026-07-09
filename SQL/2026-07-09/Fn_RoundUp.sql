SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B-Phase2-Slice1-Fn_RoundUp: Decision-A round-up bypass (setting-gated).
--   Reads PRICE_DISPLAY_DECIMALS (guard: missing/0/2/invalid -> 2, =4 -> 4).
--   setting=2: ROUND(@Price,2) + x5/x9 cents round-up (BYTE-IDENTICAL to prior behavior).
--   setting=4: ROUND(@Price,4), bypass the cents round-up (2dp-only) -> return clean 4dp price
--   (the =4 branch inserts into @Results before RETURN). (Phase-1 already widened the types to 18,4.)
CREATE OR ALTER FUNCTION [dbo].[Fn_RoundUp](@Price DECIMAL(18,4))

	RETURNS @Results TABLE (RoundedPrice DECIMAL(18,4))
AS
BEGIN
	/*
	    2026-05-04 live baseline note:
	    The previous live logic pushed any non-zero decimal value up to the next
	    x.x9 step within the current dollar. That meant 16.10 became 16.09, which
	    is no longer the desired local behavior.

	    Old live logic:
	        DECLARE @FloorPrice INT;
	        DECLARE @Difference DECIMAL(18,2);
	        DECLARE @NearestDecimal DECIMAL(18,2);
	        DECLARE @Reminder DECIMAL(18, 2);
	        DECLARE @RoundedPrice DECIMAL(18, 2)

	        SET @Price = ROUND(@Price,2)
	        SET @FloorPrice = FLOOR(@Price)
	        SET @Difference = @Price-@FloorPrice
	        SET @NearestDecimal = Ceiling(@Difference * 10) / 10;
	        SET @Reminder = @NearestDecimal - @Difference - CASE WHEN @Difference = 0 THEN 0 ELSE 0.01 END;
	        SET @RoundedPrice = @Price + @Reminder
	*/

	-- 4dp widen (consistency with widened contract; value is cents/100 so still 2dp): was DECIMAL(18,2)
	DECLARE @RoundedPrice DECIMAL(18,4);
	DECLARE @WholeCents INT;
	DECLARE @LastCentDigit INT;
	DECLARE @RoundedCents INT;
	-- 2026-07-09 Decision-A: read the active price-decimals mode (guard missing/0/2/invalid -> 2, =4 -> 4)
	DECLARE @PriceDecimals INT;
	SELECT @PriceDecimals = TRY_CAST(SettingValue AS INT) FROM SystemSetting WHERE SettingKey='PRICE_DISPLAY_DECIMALS';
	SET @PriceDecimals = CASE WHEN @PriceDecimals = 4 THEN 4 ELSE 2 END;

	/*
	    Normalize the input price to the active price-decimals mode before the selling-price rule runs.
	*/
	-- 2026-07-09 Decision-A: round to the active mode. Old: SET @Price = ROUND(@Price, 2);
	SET @Price = ROUND(@Price, @PriceDecimals);
	SET @RoundedPrice = @Price;

	-- 2026-07-09 Decision-A: the x5/x9 cents round-up is 2dp-only; bypass it in 4dp mode (return the clean
	-- 4dp price). The TVF must populate @Results before RETURN. setting=2 falls through to the cents rule below.
	IF @PriceDecimals = 4
	BEGIN
		INSERT INTO @Results(RoundedPrice) VALUES(@RoundedPrice);
		RETURN;
	END

	/*
	    Convert the price to whole cents so the final-cent rule is predictable.
	*/
	SET @WholeCents = CAST(ROUND(@Price * 100, 0) AS INT);
	SET @LastCentDigit = ABS(@WholeCents) % 10;

	/*
	    Desired local rule:
	    - final cent digit 0 stays 0
	    - final cent digit 1 through 5 rounds up to 5
	    - final cent digit 6 through 9 rounds up to 9
	*/
	IF @LastCentDigit BETWEEN 1 AND 5
		SET @RoundedCents = @WholeCents + (5 - @LastCentDigit);
	ELSE IF @LastCentDigit BETWEEN 6 AND 8
		SET @RoundedCents = @WholeCents + (9 - @LastCentDigit);
	ELSE
		SET @RoundedCents = @WholeCents;

	SET @RoundedPrice = CAST(@RoundedCents AS DECIMAL(18,2)) / 100.0;

	INSERT INTO @Results(RoundedPrice) VALUES(@RoundedPrice)

	RETURN;
END
GO

