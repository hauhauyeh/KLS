-- =============================================================================
-- ItemUnit_UpdateRecentCost -- deploy (CREATE OR ALTER). Working file per SP workflow.
-- 2026-07-18 (PO pure-cost default, step 2). Also write RecentBaseCost = pure item
--   cost (View_PurchaseHistory.BaseCost, no landed cost) with the SAME unit scaling
--   as RecentCost. RecentCost (landed TotalCost) unchanged. Signature
--   (@PurchaseId,@IsDeleted) unchanged -> SP-internal, no C#, callers unaffected.
--   Requires ItemUnit.RecentBaseCost (ItemUnit_Add_RecentBaseCost.sql runs first).
-- Baseline: KLS/SQL/2026-07-18/ItemUnit_UpdateRecentCost_live_baseline.sql
-- Plan: plan/po-item-base-cost-default-v2.md
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[ItemUnit_UpdateRecentCost]   -- EXEC dbo.ItemUnit_UpdateRecentCost @PurchaseId = 12821, @IsDeleted = 0

	@PurchaseId INT,
    @IsDeleted BIT = 0
AS
BEGIN

	SET NOCOUNT ON;

    ;WITH changeditems AS
    (
        SELECT pd.ItemId
        FROM Purchase AS p JOIN PurchaseDetail pd ON p.PurchaseId = pd.PurchaseId
        WHERE p.PurchaseId = @PurchaseId AND pd.ItemId IS NOT NULL
    )

    ,LatestCost AS
    (
        -- 2026-07-18: + BaseCost (pure item cost feeding RecentBaseCost)
        SELECT v.ItemId, TotalCost, BaseCost, RN
        FROM dbo.View_PurchaseHistory v JOIN changeditems AS i ON v.ItemId = i.ItemId
        WHERE RN = 1
        AND (
                @IsDeleted = 0
                OR v.PurchaseId <> @PurchaseId
             )
    )
    UPDATE iu
    -- 2026-07-06: threaded combine-up numerator (* MultipleToBase, guarded). Old (Mult=1 identity):
    -- SET iu.RecentCost = ROUND(lc.TotalCost / NULLIF(iu.FactorToBase, 0), 2)
    -- 2026-07-18: + RecentBaseCost = pure cost (BaseCost, no landed cost), same scaling.
    SET iu.RecentCost = ROUND(lc.TotalCost * ISNULL(NULLIF(iu.MultipleToBase, 0), 1) / NULLIF(iu.FactorToBase, 0), 2),
        iu.RecentBaseCost = ROUND(lc.BaseCost * ISNULL(NULLIF(iu.MultipleToBase, 0), 1) / NULLIF(iu.FactorToBase, 0), 2)
    FROM dbo.ItemUnit iu
    INNER JOIN LatestCost lc ON lc.ItemId = iu.ItemId;
END
