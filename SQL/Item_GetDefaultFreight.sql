CREATE OR ALTER PROCEDURE [dbo].[Item_GetDefaultFreight]
	@ItemId INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @VendorId INT;
	DECLARE @PayeeName NVARCHAR(255);
	DECLARE @PaletteFactor DECIMAL(18,2);

	SELECT TOP(1) @VendorId = p.PayeeId
	FROM Purchase AS p
	INNER JOIN PurchaseDetail AS pd ON p.PurchaseId = pd.PurchaseId
	WHERE pd.ItemId = @ItemId
	  AND pd.ShipQty > 0
	  AND FinalPrice > 0
	ORDER BY p.ArrivalDate DESC;

	SELECT @PayeeName = PayeeName
	FROM Vendor v
	INNER JOIN Payee p ON v.PayeeId = p.PayeeId
	WHERE v.PayeeId = @VendorId;

	SELECT @PaletteFactor = PaletteFactor
	FROM Item
	WHERE ItemId = @ItemId;

	SELECT
		@VendorId AS PayeeId,
		@PayeeName AS PayeeName,
		@PaletteFactor AS PaletteFactor,
		@ItemId AS ItemId;
END
