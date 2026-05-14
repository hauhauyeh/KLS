
CREATE PROCEDURE [dbo].[ItemHistory_Purchase]
	@ItemId INT,
	@PayeeId INT
AS
BEGIN
	SET NOCOUNT ON;

	SELECT top 300 *
	FROM (
		-- Received bills (from existing view)
		SELECT
			v.PurchaseDetailId,
			v.PurchaseId,
			v.PurchaseNumber,
			v.VendorDocNumber,
			v.ArrivalDate,
			p.PayeeName,
			v.ShipQty,
			v.FinalQty,
			v.Unit,
			v.FinalPrice,
			v.LandedCostPerCase,
			v.TotalCost,
			CASE WHEN v.FinalQty IS NOT NULL THEN 'Bill' ELSE 'PO' END AS Type,
			0 AS IsPdfExist
		FROM View_PurchaseHistory AS v
		INNER JOIN Payee AS p ON p.PayeeId = v.PayeeId
		WHERE v.ItemId = @ItemId

		UNION ALL

		-- Unreceived PO lines (not in view)
		SELECT
			pd.PurchaseDetailId,
			p.PurchaseId,
			p.PurchaseNumber,
			p.VendorDocNumber,
			p.ArrivalDate,
			py.PayeeName,
			pd.OrdQty0 AS ShipQty,
			NULL AS FinalQty,
			pd.Unit,
			pd.OrgPrice AS FinalPrice,
			0 AS LandedCostPerCase,
			0 AS TotalCost,
			'PO' AS Type,
			0 AS IsPdfExist
		FROM PurchaseDetail pd
		INNER JOIN Purchase p ON p.PurchaseId = pd.PurchaseId
		LEFT JOIN Payee py ON py.PayeeId = p.PayeeId
		WHERE pd.ReceiveQty IS NULL
		  AND pd.ItemId = @ItemId
		  AND pd.ItemId IS NOT NULL
	) i
	ORDER BY ArrivalDate DESC, PurchaseId DESC
END

