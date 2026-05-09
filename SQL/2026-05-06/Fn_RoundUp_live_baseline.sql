CREATE FUNCTION [dbo].[Fn_RoundUp](@Price DECIMAL(18,2))
	
	RETURNS @Results TABLE (RoundedPrice DECIMAL(18,2))
AS
BEGIN
	
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

	INSERT INTO @Results(RoundedPrice) VALUES(@RoundedPrice)

	RETURN;
END
