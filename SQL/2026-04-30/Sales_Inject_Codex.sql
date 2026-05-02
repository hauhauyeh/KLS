SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Sales_Inject codex candidate
-- Baseline: live/repo Sales_Inject with promo parent/root reverse mapping
--
-- Summary:
--   Goal: in edit mode, seed TempSales directly from persisted SalesDetail.
--   SalesDetail.LineId is now maintained correctly end-to-end, so Sales_Inject
--   no longer needs to rebuild or reinterpret line ordering.
--
-- Improvements:
--   1. Keep the inject path simple: use persisted SalesDetail.LineId order directly
--   2. Preserve parent/root reverse mapping from SalesDetail into TempSales
--   3. Refresh promo reward DisplaySort from the owner's current TempSales.LineId

CREATE OR ALTER PROCEDURE [dbo].[Sales_Inject]
    @EmpId INT,
    @SalesId INT
AS
BEGIN
    -- Section 1: initialize the edit-session cart context.
    SET NOCOUNT ON;

    DECLARE @PayeeId INT;
    SELECT @PayeeId = ShipId FROM Sales WHERE SalesId = @SalesId;

    -- Section 2: clear any existing temp-cart rows for this employee/sales pair
    -- before reseeding edit mode.
    DELETE FROM TempSales
    WHERE PayeeId = @PayeeId AND EmpId = @EmpId AND SalesId = @SalesId;

    -- Section 3: seed TempSales directly from persisted SalesDetail order.
    -- SalesDetail.LineId is now maintained correctly end-to-end, so edit mode
    -- should trust that persisted order instead of rebuilding a separate one here.
    INSERT INTO [TempSales]
           ([EmpId]
           ,[SalesId]
           ,[PayeeId]
           ,[LineType]
           ,[ItemId]
           ,[AccountId]
           ,[ItemUnitId]
           ,[Unit]
           ,[IsFree]
           ,[IsOut]
           ,[IsCRCG]
           ,[OrdQty]
           ,[ShipQty]
           ,[BillQty]
           ,[UnitPrice]
           ,[ExtTotal]
           ,[Notes]
           ,[IsTaxable]
           ,[OrgPrice]
           ,[DiscountPercent]
           ,[FactorToBase]
           ,[SalesDetailId]
           ,[ParentTempSalesId]
           ,[RootTempSalesId]
           ,[CartLineType]
           ,[IsSystemManaged]
           ,[DisplaySort])
    SELECT
            @EmpId
           ,[SalesId]
           ,@PayeeId
           ,[LineType]
           ,[ItemId]
           ,[AccountId]
           ,[ItemUnitId]
           ,[Unit]
           ,CASE WHEN (sd.BillQty = 0 AND sd.ShipQty != 0) THEN 1 ELSE 0 END -- Free
           ,CASE WHEN (sd.BillQty = 0 AND sd.ShipQty = 0) THEN 1 ELSE 0 END  -- Out
           ,CASE WHEN (sd.BillQty != 0 AND sd.ShipQty = 0) THEN 1 ELSE 0 END -- Credit
           ,[OrdQty]
           ,[ShipQty]
           ,[BillQty]
           ,[UnitPrice]
           ,[ExtTotal]
           ,[Notes]
           ,[IsTaxable]
           ,[OrgPrice]
           ,[DiscountPercent]
           ,[FactorToBase]
           ,[SalesDetailId]
           ,NULL  -- ParentTempSalesId (populated below)
           ,NULL  -- RootTempSalesId (populated below)
           ,ISNULL([CartLineType], 'MAIN')
           ,ISNULL([IsSystemManaged], 0)
           ,[DisplaySort]
    FROM SalesDetail AS sd WHERE SalesId=@SalesId ORDER BY sd.LineId

    -- Section 4: reverse-map parent/root references using SalesDetailId.
    -- TempSales.SalesDetailId stores the source SalesDetailId, so the edit cart
    -- can restore owner/reward linkage after the insert.
    UPDATE ts
    SET ts.ParentTempSalesId = pts.TempSalesId,
        ts.RootTempSalesId = ISNULL(rts.TempSalesId, pts.TempSalesId)
    FROM TempSales ts
    INNER JOIN SalesDetail sd ON sd.SalesDetailId = ts.SalesDetailId
    LEFT JOIN TempSales pts ON pts.SalesDetailId = sd.ParentSalesDetailId
        AND pts.EmpId = @EmpId AND pts.SalesId = @SalesId AND pts.PayeeId = @PayeeId
    LEFT JOIN TempSales rts ON rts.SalesDetailId = sd.RootSalesDetailId
        AND rts.EmpId = @EmpId AND rts.SalesId = @SalesId AND rts.PayeeId = @PayeeId
    WHERE ts.EmpId = @EmpId AND ts.SalesId = @SalesId AND ts.PayeeId = @PayeeId
      AND sd.ParentSalesDetailId IS NOT NULL;

    -- Refresh DisplaySort on PROMO_REWARD rows to match owner's current LineId
    UPDATE ts
    SET ts.DisplaySort = owner.LineId
    FROM TempSales ts
    INNER JOIN TempSales owner ON owner.TempSalesId = ts.ParentTempSalesId
    WHERE ts.CartLineType = 'PROMO_REWARD'
      AND ts.EmpId = @EmpId
      AND ts.SalesId = @SalesId
      AND ts.PayeeId = @PayeeId;

    -- Section 5: refresh reward DisplaySort from the owner's current temp-cart
    -- LineId so promo display grouping stays aligned in edit mode.
END
GO
