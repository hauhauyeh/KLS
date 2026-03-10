-- Phase 2F: Sales_Inject — Reverse-map parent/root + refresh DisplaySort on PROMO_REWARD
-- Changes:
--   1. After INSERT INTO TempSales, UPDATE parent/root references using SalesDetailId mapping
--   2. Refresh DisplaySort on PROMO_REWARD rows to match owner's current LineId

ALTER PROCEDURE [dbo].[Sales_Inject]
    @EmpId INT,
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @PayeeId INT
    SELECT @PayeeId=ShipId FROM Sales WHERE SalesId=@SalesId

    DELETE FROM TempSales WHERE PayeeId=@PayeeId AND EmpId=@EmpId AND SalesId=@SalesId

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
           ,CASE WHEN (sd.BillQty=0 AND sd.ShipQty!=0) THEN 1 ELSE 0 END --Free
           ,CASE WHEN (sd.BillQty=0 AND sd.ShipQty=0) THEN 1 ELSE 0 END  --Out
           ,CASE WHEN (sd.BillQty!=0 AND sd.ShipQty=0) THEN 1 ELSE 0 END --Credit
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
           ,[CartLineType]
           ,[IsSystemManaged]
           ,[DisplaySort]
    FROM SalesDetail AS sd WHERE SalesId=@SalesId ORDER BY sd.LineId

    -- Phase 2E: Reverse-map parent/root references using SalesDetailId
    -- TempSales.SalesDetailId stores the source SalesDetailId, so we can join directly
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
END
