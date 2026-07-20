
CREATE   PROCEDURE [dbo].[ItemUnit_UpdateRecentCost]   -- EXEC dbo.ItemUnit_UpdateRecentCost @PurchaseId = 12821, @IsDeleted = 0

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

