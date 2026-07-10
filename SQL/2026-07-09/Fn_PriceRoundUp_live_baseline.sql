
CREATE PROCEDURE [dbo].[Fn_PriceRoundUp]
	
	@Price DECIMAL(18,2),
	@RoundedPrice DECIMAL(18,2) OUTPUT
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @PriceINT INT;
	DECLARE @Difference DECIMAL(18,2);
	DECLARE @IsPriceRoundup BIT

	SET @Price = ROUND(@Price,2)

	SET @RoundedPrice=@Price

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



