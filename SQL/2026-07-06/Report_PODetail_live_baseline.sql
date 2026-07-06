-- =============================================================================
-- Report_PODetail -- LIVE BASELINE captured 2026-07-06 (frozen rollback ref).
-- Sole rollback artifact for the ItemUnit-ratio-source change. Do not edit.
-- Deployable as-is (DROP + CREATE) to restore the pre-change proc.
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[Report_PODetail]
GO

CREATE PROCEDURE [dbo].[Report_PODetail] --[dbo].[Report_PODetail] 138

	@PurchaseId INT
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

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
	pd.BaseFinalQty,
	pd.FactorToBase,
	i.ItemName,
	i.CaseWeight,
	i.CaseVolumeInCubicMeter,
	i.PackSize,
	i.ItemCode
	FROM PurchaseDetail AS pd INNER JOIN Item AS i ON i.ItemId=pd.ItemId
	WHERE pd.PurchaseId = @PurchaseId

	UNION ALL

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
	pd.BaseFinalQty,
	pd.FactorToBase,
	a.AccountName,
	0,
	0,
	null,
	null
	FROM PurchaseDetail AS pd INNER JOIN Account a ON a.AccountId=pd.AccountId
	WHERE pd.PurchaseId=@PurchaseId
	--ORDER BY ItemCode

END
