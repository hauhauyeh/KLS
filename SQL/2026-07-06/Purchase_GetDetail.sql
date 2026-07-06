-- =============================================================================
-- Purchase_GetDetail -- deploy (CREATE OR ALTER). Working file per SP workflow.
-- 2026-07-06: source the unit ratio from ItemUnit (source of truth), drop the
--   pd.FactorToBase snapshot read; add MultipleToBase (for the C# BaseFinalQty getter's
--   * MultipleToBase / FactorToBase). Consumed only by PurchaseDetailDto.TotalCases
--   -> Purchase Quick View ("Total Cases"). Item block LEFT JOINs ItemUnit (source of
--   truth; LEFT so a hypothetical orphan item line isn't dropped -- 0 exist today).
--   Account block needs NO ratio (no inventory / no unit) -> constant 1/1, no join.
--   ISNULL(...,1) is required so EF materializes a non-null int for the C# MultipleToBase.
--   Identity today (all MultipleToBase=1, immutable ratios => iu.FactorToBase == snapshot
--   for non-drift lines). Vertical slice: pairs with PurchaseDetailList.cs field + getter.
-- Baseline: KLS/SQL/2026-07-06/Purchase_GetDetail_live_baseline.sql
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[Purchase_GetDetail] --[Purchase_GetDetail] 80053

	@PurchaseId INT
AS
BEGIN

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
	-- 2026-07-06: was pd.FactorToBase (snapshot); now sourced from ItemUnit.
	ISNULL(iu.FactorToBase, 1)   AS FactorToBase,
	ISNULL(iu.MultipleToBase, 1) AS MultipleToBase,
	i.ItemName,
	i.ItemBoxDesc
	FROM PurchaseDetail AS pd
		INNER JOIN Item AS i ON i.ItemId = pd.ItemId
		LEFT JOIN ItemUnit AS iu ON iu.ItemUnitId = pd.ItemUnitId
	WHERE pd.PurchaseId = @PurchaseId

	UNION all

	-- Account block: account lines carry no inventory/unit -> no ratio (constant 1/1),
	-- BaseFinalQty is never summed into TotalCases (LineType='I' only).
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
	-- 2026-07-06: was pd.FactorToBase; account lines have no ratio -> constant 1/1.
	CAST(1 AS DECIMAL(18,6)) AS FactorToBase,
	1                        AS MultipleToBase,
	c.AccountName,
	null
	FROM PurchaseDetail AS pd INNER JOIN Account AS C ON c.AccountId=pd.AccountId
	WHERE pd.PurchaseId = @PurchaseId
	ORDER BY pd.PurchaseDetailId

END
