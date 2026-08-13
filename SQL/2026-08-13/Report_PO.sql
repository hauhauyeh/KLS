SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_PO] --[dbo].[Report_PO] 68

	@PurchaseId INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT PurchaseId,PurchaseNumber,po.PayeeId,po.VendorDocNumber,po.FactorPO,PurchaseDate,ArrivalDate,VendorTotal,
	p.PayeeName,
	p.Address,
	p.City,
	p.State,
	p.ZipCode,
	p.Phone1,
	p.Country
	FROM Purchase AS po inner JOIN Payee AS P on po.PayeeId=p.PayeeId
	WHERE PurchaseId=@PurchaseId

END


