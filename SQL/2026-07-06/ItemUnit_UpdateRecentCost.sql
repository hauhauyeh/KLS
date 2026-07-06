-- =============================================================================
-- ItemUnit_UpdateRecentCost -- deploy (CREATE OR ALTER). Working file per SP workflow.
-- 2026-07-06 (price phase, vertical 4 -- the cost producer, last SP). Thread combine-up
--   numerator into the per-unit RecentCost: a non-base unit's cost scales base * MultipleToBase
--   / FactorToBase. UPDATE already joins iu (=ItemUnit), so add ISNULL(NULLIF(iu.MultipleToBase,0),1)
--   (rollout guard). Signature (@PurchaseId,@IsDeleted) unchanged -> SP-internal, no C#, callers
--   unaffected. Identity for all production data (Mult=1); only CHIFT's 10lbcase (Mult=10) differs
--   (1 row -- parity-verified).
-- Baseline: KLS/SQL/2026-07-06/ItemUnit_UpdateRecentCost_live_baseline.sql
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
        SELECT v.ItemId, TotalCost, RN
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
    SET iu.RecentCost = ROUND(lc.TotalCost * ISNULL(NULLIF(iu.MultipleToBase, 0), 1) / NULLIF(iu.FactorToBase, 0), 2)
    FROM dbo.ItemUnit iu
    INNER JOIN LatestCost lc ON lc.ItemId = iu.ItemId;
END
