CREATE PROCEDURE [dbo].[Get_ItemPriceByCustomer]
	
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
		[DefaultPrice] DECIMAL(18,2),
		[FactorToBase] DECIMAL(18,6),
		[IsTaxable] BIT
		--[ListPrice] DECIMAL(18,2),
		--[Discount] DECIMAL(18,4)
	)

	DECLARE @ShipDate DATE = GETDATE();
	DECLARE @DefaultUnit NVARCHAR(50);
	DECLARE @DefaultPrice DECIMAL(18,2);
	DECLARE @FactorToBase DECIMAL(18,6);
	DECLARE @IsTaxable BIT
	DECLARE @ListPrice DECIMAL(18,2) = 0
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

