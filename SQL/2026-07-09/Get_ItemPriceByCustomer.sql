SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- KLS-4DP-B5-Get_ItemPriceByCustomer: 4-decimal pricing Section B Phase-1 (storage/type widen, inert).
--   Widen the DefaultPrice/ListPrice carriers 2dp -> 4dp so a 4dp price from Fn_GetPrice (now 18,4) survives
--   into TempSales_AddLine instead of re-truncating here. Inert today: Fn_GetPrice still emits 2dp (its ROUNDs
--   are Phase-2). @ListPrice is currently dead (source + output commented) -- widened for consistency.
CREATE OR ALTER PROCEDURE [dbo].[Get_ItemPriceByCustomer]
	
	@PayeeId INT,
	@ItemId INT,
	@ItemUnitId INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	DECLARE @PriceTable TABLE (
		[ItemId] INT,
		[ItemUnitId] INT,
		[DefaultUnit] NVARCHAR(50),
		-- 4dp widen: was [DefaultPrice] DECIMAL(18,2)
		[DefaultPrice] DECIMAL(18,4),
		[FactorToBase] DECIMAL(18,6),
		[IsTaxable] BIT
		--[ListPrice] DECIMAL(18,2),
		--[Discount] DECIMAL(18,4)
	)

	DECLARE @ShipDate DATE = GETDATE();
	DECLARE @DefaultUnit NVARCHAR(50);
	-- 4dp widen: was DECIMAL(18,2)
	DECLARE @DefaultPrice DECIMAL(18,4);
	DECLARE @FactorToBase DECIMAL(18,6);
	DECLARE @IsTaxable BIT
	-- 4dp widen (currently dead): was DECIMAL(18,2)
	DECLARE @ListPrice DECIMAL(18,4) = 0
	DECLARE @Discount DECIMAL(18,4)
	
	SELECT @ItemUnitId=ItemUnitId,
	@DefaultUnit=Unit,
	@DefaultPrice=Price,
	@FactorToBase=FactorToBase
	--@ListPrice=ListPrice,
	--@Discount=Discount 
	FROM dbo.Fn_GetPrice(@PayeeId,@ItemId,@ItemUnitId);

	SELECT @IsTaxable=IsTaxable FROM dbo.Fn_IsItemTaxable(@ItemId,@ShipDate,@PayeeId)

	INSERT INTO @PriceTable(ItemId,ItemUnitId,DefaultUnit,DefaultPrice,FactorToBase,IsTaxable)
	VALUES(@ItemId,@ItemUnitId,@DefaultUnit,@DefaultPrice,@FactorToBase,@IsTaxable)

	SELECT * FROM @PriceTable

END
GO

