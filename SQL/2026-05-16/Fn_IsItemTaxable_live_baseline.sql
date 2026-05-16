CREATE FUNCTION [dbo].[Fn_IsItemTaxable](@ItemId INT,@ShipDate DATE,@PayeeId INT)

	RETURNS @Results TABLE (
		ItemId INT NOT NULL,
		IsTaxable BIT NOT NULL
	)
AS
BEGIN

	DECLARE @IsTaxable BIT = 0;	
	DECLARE @RCNumber NVARCHAR(50);
	DECLARE @RCExpiredDate DATE;
	DECLARE @IsHRTaxable BIT;

	SELECT @RCExpiredDate=RCExpireDate,
	@IsHRTaxable=IsHRTaxable,
	@RCNumber=RCNumber
	FROM Customer WHERE PayeeId = @PayeeId

	SELECT @IsTaxable=IsTaxable FROM Item WHERE ItemId=@ItemId

	IF (@RCNumber IS NOT NULL AND @ShipDate<=@RCExpiredDate)
	BEGIN	
		SET @IsTaxable = 0;

		IF @IsHRTaxable = 1
			SELECT @IsTaxable=IsHRExempt FROM Item WHERE ItemId=@ItemId
	END
	ELSE IF @PayeeId!=(SELECT PayeeId FROM Payee WHERE PayeeName='Cash Ticket')
	BEGIN
		SELECT @IsTaxable=IsHRExempt FROM Item WHERE ItemId=@ItemId
	END

	INSERT INTO @Results(ItemId,IsTaxable) values(@ItemId,@IsTaxable)

	RETURN
END


