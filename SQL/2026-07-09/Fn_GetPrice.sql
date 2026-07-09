SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B1-Fn_GetPrice: 4-decimal pricing §B Phase-1 (storage/type widen, inert).
--   Widen internal price vars + RETURNS Price/ListPrice cols 2dp -> 4dp. Inert: output @FinalPrice always
--   passes ROUND(@Price,2) (l.87, unchanged) and Fn_RoundUp, so emitted value stays 2dp on today's data.
--   The 4 unit-price ROUND(,2) sites (l.55/60/85/87) are LEFT for Phase-2.
CREATE OR ALTER FUNCTION [dbo].[Fn_GetPrice](@PayeeId INT,@ItemId INT,@ItemUnitId INT)
	RETURNS @Results TABLE (
		ItemUnitId INT,
		Unit NVARCHAR(50),
		-- 4dp widen: was Price DECIMAL(18,2)
		Price DECIMAL(18,4),
		FactorToBase DECIMAL(18,6),
		-- 4dp widen: was ListPrice DECIMAL(18,2)
		ListPrice DECIMAL(18,4),
		Discount DECIMAL(18,4)
	)
AS
BEGIN
	DECLARE @Unit NVARCHAR(50);
	-- 4dp widen: was DECIMAL(18,2)
	DECLARE @Price DECIMAL(18,4) = 0;
	DECLARE @FactorToBase DECIMAL(18,6) = 1;
	DECLARE @ShareQuoteId INT;
	-- 4dp widen: was DECIMAL(18,2)
	DECLARE @TargetPrice DECIMAL(18,4);
	DECLARE @HasOwnList BIT;
	DECLARE @MarkupPercent DECIMAL(18,4);
	DECLARE @IsMarkupAdd BIT=0;
	DECLARE @Discount DECIMAL(18,4);
	-- 4dp widen: was DECIMAL(18,2)
	DECLARE @ListPrice DECIMAL(18,4);
	-- 4dp widen: was DECIMAL(18,2)
	DECLARE @P1 DECIMAL(18,4)=0;
	-- 4dp widen: was DECIMAL(18,2)
	DECLARE @RecentCost DECIMAL(18,4)=0;
	DECLARE @BaseMarkup DECIMAL(18,4)=0;
	DECLARE @SharedCustBaseMarkup DECIMAL(18,4)=0;
	DECLARE @IsShareBasePrice BIT=0;
	DECLARE @IsBaseToRecentCost BIT;

	SELECT @ShareQuoteId=ShareQuoteId,
	@HasOwnList=HasOwnList,
	@BaseMarkup=BaseMarkup,
	@IsShareBasePrice=IsShareBasePrice,
	@IsBaseToRecentCost=IsBaseToRecentCost
	FROM Customer
	WHERE PayeeId = @PayeeId;

	--if unit is not pass then get default sales unit
	IF @ItemUnitId IS NULL
		SELECT @ItemUnitId = ItemUnitId FROM ItemUnit WHERE ItemId=@ItemId AND IsDefaultSalesUnit=1;

	SELECT @P1=ISNULL(P1,0),
	@RecentCost=ISNULL(RecentCost,0),
	@Unit=Unit,
	@FactorToBase=FactorToBase,
	@ListPrice = P1
	FROM ItemUnit
	WHERE ItemUnitId=@ItemUnitId;

	IF @IsBaseToRecentCost=1
		SET @P1 = @RecentCost;

	SELECT @SharedCustBaseMarkup=BaseMarkup FROM Customer WHERE PayeeId=@ShareQuoteId;

	IF @BaseMarkup IS NOT NULL AND @BaseMarkup!=0 --use default own basemarkup
		SET @Price=Round(@P1*(1+@BaseMarkup),2);
	ELSE
		SET @Price=@P1;

	IF @IsShareBasePrice=1 AND @SharedCustBaseMarkup IS NOT NULL and @SharedCustBaseMarkup<>0 --use share default basemarkup
		SET @Price=ROUND(@P1*(1+@SharedCustBaseMarkup),2);

	IF @ShareQuoteId IS NOT NULL	--use shared list markup
	BEGIN
		SELECT @TargetPrice=TargetPrice,
		@MarkupPercent=MarkupPercent
		FROM ItemQuote
		WHERE ItemUnitId=@ItemUnitId AND PayeeId=@ShareQuoteId;

		IF (@TargetPrice IS NOT NULL AND @TargetPrice <> 0)
			SET @Price = @TargetPrice;
	END;

	IF @HasOwnList = 1	-- use own list markup
	BEGIN
		SELECT @TargetPrice=TargetPrice,
		@MarkupPercent=MarkupPercent
		FROM ItemQuote
		WHERE ItemUnitId=@ItemUnitId AND PayeeId=@PayeeId;

		IF (@TargetPrice IS NOT NULL AND @TargetPrice <> 0)
			SET @Price = @TargetPrice;
	END;

	IF @MarkupPercent IS NOT NULL --AND @MarkupPercent <> 0
		SET @Price=ROUND(@P1*(1+@MarkupPercent),2);

	SET @Price = ISNULL(ROUND(@Price,2),0);

	-- 4dp widen: was DECIMAL(18,2)
	DECLARE @FinalPrice DECIMAL(18,4) = @Price;
	DECLARE @IsPriceRoundup BIT;

	SELECT @IsPriceRoundup=SettingValue FROM SystemSetting WHERE SettingKey='ITEM_PRICE_ROUNDUP';

	IF @IsPriceRoundup=1
		SELECT @FinalPrice=RoundedPrice FROM Fn_RoundUp(@Price);

	--Calculate discount
	--IF @ListPrice <> 0
	--	SET @Discount = (@ListPrice - @FinalPrice) / @ListPrice

	INSERT INTO @Results(ItemUnitId,Unit,Price,FactorToBase,Discount)
	VALUES(@ItemUnitId,@Unit,@FinalPrice,@FactorToBase,@Discount);

	RETURN;
END;
GO

