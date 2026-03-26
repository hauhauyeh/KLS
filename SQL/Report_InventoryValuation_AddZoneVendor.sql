CREATE OR ALTER PROCEDURE [dbo].[Report_InventoryValuation]
(
    @CategoryId INT = NULL,
    @Zone       NVARCHAR(50) = NULL,
    @PayeeId    INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH FutureSales AS (
        SELECT sd.ItemId, SUM(sd.BaseShipQty) AS FutureSalesQty
        FROM SalesDetail sd
        INNER JOIN Sales s ON s.SalesId = sd.SalesId
        WHERE s.ShipDate > CAST(GETDATE() AS DATE)
          AND sd.ItemId IS NOT NULL
        GROUP BY sd.ItemId
    )
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
        (i.LCloseQty - ISNULL(fs.FutureSalesQty, 0)) AS OnHand,
        i.LAvgCost,
        ((i.LCloseQty - ISNULL(fs.FutureSalesQty, 0)) * ISNULL(i.LAvgCost, 0)) AS Value,
        i.PreferredVendorId,
        py.PayeeName AS VendorName
    FROM Item i
    INNER JOIN ItemUnit iu ON iu.ItemId = i.ItemId AND iu.IsBaseUnit = 1
    LEFT JOIN View_Category vc ON vc.CategoryId = i.CategoryId
    LEFT JOIN ItemStorage ist ON ist.StorageId = i.StorageId
    LEFT JOIN Payee py ON py.PayeeId = i.PreferredVendorId
    LEFT JOIN FutureSales fs ON fs.ItemId = i.ItemId
    WHERE i.IsDeleted = 0
      AND i.Inactive = 0
      AND (@CategoryId IS NULL OR i.CategoryId = @CategoryId
           OR i.CategoryId IN (SELECT CategoryId FROM ItemCategory WHERE ParentId = @CategoryId))
      AND (@Zone IS NULL OR ist.Zone = @Zone)
      AND (@PayeeId IS NULL OR i.PreferredVendorId = @PayeeId)
    ORDER BY vc.Sort0, vc.Sort1, i.ItemName;
END
GO
