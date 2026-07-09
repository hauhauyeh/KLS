SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B1-Fn_RoundUp: 4-decimal pricing §B Phase-1 (storage/type widen, inert).
--   Widen @Price param + RETURNS RoundedPrice col 2dp -> 4dp. Type-only: l.35 ROUND(@Price,2) caps the input
--   and the output is cents/100 (inherently 2dp). The .99 cent-ending rule (Decision-A) is untouched.
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

	/*
	    Normalize the input price to two decimals before the selling-price rule runs.
	*/
	SET @Price = ROUND(@Price, 2);
	SET @RoundedPrice = @Price;

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

