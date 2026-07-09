-- =============================================================================
-- Purchase_GetDetail -- LIVE BASELINE captured 2026-07-06 (frozen rollback ref).
-- Sole rollback artifact for the ItemUnit-ratio-source change. Do not edit.
-- Deployable as-is (DROP + CREATE) to restore the pre-change proc.
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Purchase_GetDetail]
GO

CREATE PROCEDURE [dbo].[Purchase_GetDetail] --[Purchase_GetDetail] 80053

	@PurchaseId INT
AS
BEGIN

	SELECT
	pd.PurchaseDetailId,
	pd.PurchaseId,
	pd.ItemId,
	pd.LineType,
	pd.Unit,
	pd.OrdQty0,
	pd.ShipQty,
	pd.BillQty,
	pd.BillPrice,
	pd.OrdQty1,
	pd.ReceiveQty,
	pd.FinalQty,
	pd.FinalPrice,
	pd.Notes,
	pd.FactorToBase,
	i.ItemName,
	i.ItemBoxDesc
	FROM PurchaseDetail AS pd INNER JOIN Item AS i ON i.ItemId=pd.ItemId
	WHERE pd.PurchaseId = @PurchaseId

	UNION all

	SELECT
	pd.PurchaseDetailId,
	pd.PurchaseId,
	pd.ItemId,
	pd.LineType,
	pd.Unit,
	pd.OrdQty0,
	pd.ShipQty,
	pd.BillQty,
	pd.BillPrice,
	pd.OrdQty1,
	pd.ReceiveQty,
	pd.FinalQty,
	pd.FinalPrice,
	pd.Notes,
	pd.FactorToBase,
	c.AccountName,
	null
	FROM PurchaseDetail AS pd INNER JOIN Account AS C ON c.AccountId=pd.AccountId
	WHERE pd.PurchaseId = @PurchaseId
	ORDER BY pd.PurchaseDetailId

END
