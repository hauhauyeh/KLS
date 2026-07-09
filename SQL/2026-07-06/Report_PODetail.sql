-- =============================================================================
-- Report_PODetail -- deploy (CREATE OR ALTER). Working file per SP workflow.
-- 2026-07-06: source the unit ratio from ItemUnit (source of truth), drop the
--   pd.FactorToBase snapshot read; add MultipleToBase (for the C# BaseBillQty getter's
--   * MultipleToBase / FactorToBase). Feeds the PO PDF footer totals only
--   (TotalCases / TotalWeight / TotalVolume, all via BaseBillQty). Item block LEFT JOINs
--   ItemUnit (source of truth; LEFT so a hypothetical orphan item line isn't dropped).
--   Account block needs NO ratio (no inventory/unit) -> constant 1/1, no join.
--   ISNULL(...,1) required so EF materializes a non-null int for the C# MultipleToBase.
--   Also DROPPED the vestigial pd.BaseFinalQty select (the RptPODetail DTO never mapped it).
--   Identity today (all MultipleToBase=1); pre-immutability drift POs shift to current ratio.
-- Baseline: KLS/SQL/2026-07-06/Report_PODetail_live_baseline.sql
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Report_PODetail] --[dbo].[Report_PODetail] 138

	@PurchaseId INT
AS
BEGIN
	SET NOCOUNT ON;

	-- Item block: ratio from ItemUnit (source of truth) via the line's ItemUnitId.
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
	-- 2026-07-06: dropped vestigial pd.BaseFinalQty (DTO never mapped it);
	-- was pd.FactorToBase (snapshot) -> now sourced from ItemUnit.
	ISNULL(iu.FactorToBase, 1)   AS FactorToBase,
	ISNULL(iu.MultipleToBase, 1) AS MultipleToBase,
	i.ItemName,
	i.CaseWeight,
	i.CaseVolumeInCubicMeter,
	i.PackSize,
	i.ItemCode
	FROM PurchaseDetail AS pd
		INNER JOIN Item AS i ON i.ItemId = pd.ItemId
		LEFT JOIN ItemUnit AS iu ON iu.ItemUnitId = pd.ItemUnitId
	WHERE pd.PurchaseId = @PurchaseId

	UNION ALL

	-- Account block: account lines carry no inventory/unit -> no ratio (constant 1/1).
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
	-- 2026-07-06: dropped vestigial pd.BaseFinalQty; account lines have no ratio -> constant 1/1.
	CAST(1 AS DECIMAL(18,6)) AS FactorToBase,
	1                        AS MultipleToBase,
	a.AccountName,
	0,
	0,
	null,
	null
	FROM PurchaseDetail AS pd INNER JOIN Account a ON a.AccountId=pd.AccountId
	WHERE pd.PurchaseId=@PurchaseId
	--ORDER BY ItemCode

END
