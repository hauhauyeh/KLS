SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- 2026-08-29 IsManualPrice pass-through (plan-reprice-open-orders-v1 slice 2). Baseline: Sales_Inject_live_baseline.sql
-- Sales_Inject working file
CREATE OR ALTER PROCEDURE [dbo].[Sales_Inject]
    @EmpId INT,
    @SalesId INT
AS
BEGIN
    -- Section 1: initialize the edit-session cart context.
    SET NOCOUNT ON;

    DECLARE @PayeeId INT;
    DECLARE @ParentSalesNumber INT;

    /*
        Load the edit-session header context once. Credit memo edit mode needs
        the persisted Sales.ParentSalesNumber carried into TempSales so the cart
        can display the real parent invoice instead of "No Parent".
    */
    SELECT
        @PayeeId = ShipId,
        @ParentSalesNumber = ParentSalesNumber
    FROM Sales
    WHERE SalesId = @SalesId;

    -- Section 2: clear any existing temp-cart rows for this employee/sales pair
    -- before reseeding edit mode.
    DELETE FROM TempSales
    WHERE PayeeId = @PayeeId AND EmpId = @EmpId AND SalesId = @SalesId;

    /*
        2026-05-04 historical note:
        The previous live insert did not populate TempSales.ParentSalesNumber.
        That caused credit memo edit mode to show "No Parent" in the cart even
        when the Sales header already had a valid ParentSalesNumber.

        Old insert column list omitted ParentSalesNumber entirely.
    */

    -- Section 3: seed TempSales directly from persisted SalesDetail order.
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
           ,[ParentSalesNumber]
           ,[SalesDetailId]
           ,[ParentTempSalesId]
           ,[RootTempSalesId]
           ,[CartLineType]
           ,[IsSystemManaged]
           ,[DisplaySort]
           ,[IsManualPrice])   -- 2026-08-29 IsManualPrice pass-through (plan-reprice-open-orders-v1 slice 2)
    SELECT
            @EmpId
           ,[SalesId]
           ,@PayeeId
           ,[LineType]
           ,[ItemId]
           ,[AccountId]
           ,[ItemUnitId]
           ,[Unit]
           ,CASE WHEN (sd.BillQty = 0 AND sd.ShipQty != 0) THEN 1 ELSE 0 END
           ,CASE WHEN (sd.BillQty = 0 AND sd.ShipQty = 0) THEN 1 ELSE 0 END
           ,CASE WHEN (sd.BillQty != 0 AND sd.ShipQty = 0) THEN 1 ELSE 0 END
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
           ,@ParentSalesNumber
           ,[SalesDetailId]
           ,NULL
           ,NULL
           ,ISNULL([CartLineType], 'MAIN')
           ,ISNULL([IsSystemManaged], 0)
           ,[DisplaySort]
           ,[IsManualPrice]
    FROM SalesDetail AS sd WHERE SalesId=@SalesId ORDER BY sd.LineId;

    -- Section 4: reverse-map parent/root references using SalesDetailId.
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

    -- Section 5: refresh reward DisplaySort from the owner's current temp-cart LineId.
    UPDATE ts
    SET ts.DisplaySort = owner.LineId
    FROM TempSales ts
    INNER JOIN TempSales owner ON owner.TempSalesId = ts.ParentTempSalesId
    WHERE ts.CartLineType = 'PROMO_REWARD'
      AND ts.EmpId = @EmpId
      AND ts.SalesId = @SalesId
      AND ts.PayeeId = @PayeeId;
END

GO
