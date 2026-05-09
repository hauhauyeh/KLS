-- Sales_Inject live baseline captured on 2026-05-04 before credit memo parent-number inject fix.
CREATE PROCEDURE [dbo].[Sales_Inject]
    @EmpId INT,
    @SalesId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PayeeId INT;
    SELECT @PayeeId = ShipId FROM Sales WHERE SalesId = @SalesId;

    DELETE FROM TempSales
    WHERE PayeeId = @PayeeId AND EmpId = @EmpId AND SalesId = @SalesId;

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
           ,[SalesDetailId]
           ,NULL
           ,NULL
           ,ISNULL([CartLineType], 'MAIN')
           ,ISNULL([IsSystemManaged], 0)
           ,[DisplaySort]
    FROM SalesDetail AS sd WHERE SalesId=@SalesId ORDER BY sd.LineId;
END
