CREATE PROCEDURE [dbo].[Shipment_AssignedPurchase]

	@ShipmentId INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT ROW_NUMBER() OVER(ORDER BY ShipmentPurchaseId) AS Id,
	sp.ShipmentPurchaseId,
	pr.PurchaseNumber,
	pr.ArrivalDate,
	pr.PurchaseTotal,
	pr.IsLocked,
	p.PayeeName
	FROM ShipmentPurchase sp 
	INNER JOIN Purchase pr ON sp.PurchaseId = pr.PurchaseId
	INNER JOIN Payee p ON pr.PayeeId = p.PayeeId
	WHERE sp.ShipmentId = @ShipmentId
	ORDER BY sp.ShipmentPurchaseId

END



