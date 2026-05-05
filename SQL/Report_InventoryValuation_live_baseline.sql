CREATE PROCEDURE [dbo].[Report_InventoryValuation]
(
    @CategoryId INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ROW_NUMBER() OVER (ORDER BY vc.Sort0, vc.Sort1, i.ItemName) AS AutoId,
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        vc.Cat0,
        vc.Cat1,
        vc.Sort0,
        vc.Sort1,
        iu.Unit,
        (i.LCloseQty - ISNULL(i.FutureQty, 0)) AS OnHand,
        i.LAvgCost,
        ((i.LCloseQty - ISNULL(i.FutureQty, 0)) * ISNULL(i.LAvgCost, 0)) AS Value,
        i.PreferredVendorId,
        py.PayeeName AS VendorName
    FROM Item i
    INNER JOIN ItemUnit iu ON iu.ItemId = i.ItemId AND iu.IsBaseUnit = 1
    LEFT JOIN View_Category vc ON vc.CategoryId = i.CategoryId
    LEFT JOIN Payee py ON py.PayeeId = i.PreferredVendorId
    WHERE i.IsDeleted = 0
      AND i.Inactive = 0
      AND (@CategoryId IS NULL OR i.CategoryId = @CategoryId
           OR i.CategoryId IN (SELECT CategoryId FROM ItemCategory WHERE ParentId = @CategoryId))
    ORDER BY vc.Sort0, vc.Sort1, i.ItemName;
END
