-- =============================================================================
-- ItemUnit_UpdateRecentCost -- LIVE BASELINE captured 2026-07-06 (frozen rollback ref).
-- Sole rollback artifact for the MultipleToBase threading. Do not edit.
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[ItemUnit_UpdateRecentCost]
GO

 
CREATE PROCEDURE [dbo].[ItemUnit_UpdateRecentCost]
 
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
    SET iu.RecentCost = ROUND(lc.TotalCost / NULLIF(iu.FactorToBase, 0), 2)
    FROM dbo.ItemUnit iu
    INNER JOIN LatestCost lc ON lc.ItemId = iu.ItemId;
END
