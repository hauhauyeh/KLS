CREATE OR ALTER PROCEDURE [dbo].[Report_InventoryStatus]
(
    @Search       NVARCHAR(100) = NULL,
    @CategoryId   INT = NULL,
    @Zone         NVARCHAR(50) = NULL,
    @ShowInactive BIT = 0,
    @PayeeId      INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH FutureIncoming AS (
        SELECT pd.ItemId, SUM(pd.OrdQty0 - ISNULL(pd.BaseReceiveQty, 0)) AS IncomingQty
        FROM PurchaseDetail pd
        INNER JOIN Purchase p ON p.PurchaseId = pd.PurchaseId
        WHERE p.StageId IN (1, 2, 3, 4)
          AND pd.ItemId IS NOT NULL
          AND (pd.OrdQty0 - ISNULL(pd.BaseReceiveQty, 0)) > 0
        GROUP BY pd.ItemId
    ),
    FutureSales AS (
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
        ist.DisplayName AS StorageName,
        iu.Unit,
        (i.LCloseQty - ISNULL(fs.FutureSalesQty, 0)) AS OnHand,
        ISNULL(fs.FutureSalesQty, 0) AS FutureSales,
        ISNULL(fi.IncomingQty, 0) AS TotalIncoming,
        i.LAvgCost,
        i.LInventoryValue,
        i.RefillInventory,
        i.ActualSaftyInventory,
        i.M0,
        i.M1,
        i.M2,
        i.M3,
        i.YTD,
        i.ExpiryDate,
        i.Inactive,
        i.PreferredVendorId,
        py.PayeeName AS VendorName
    FROM Item i
    INNER JOIN ItemUnit iu ON iu.ItemId = i.ItemId AND iu.IsBaseUnit = 1
    LEFT JOIN View_Category vc ON vc.CategoryId = i.CategoryId
    LEFT JOIN ItemStorage ist ON ist.StorageId = i.StorageId
    LEFT JOIN Payee py ON py.PayeeId = i.PreferredVendorId
    LEFT JOIN FutureIncoming fi ON fi.ItemId = i.ItemId
    LEFT JOIN FutureSales fs ON fs.ItemId = i.ItemId
    WHERE i.IsDeleted = 0
      AND (@ShowInactive = 1 OR i.Inactive = 0)
      AND (@CategoryId IS NULL OR i.CategoryId = @CategoryId
           OR i.CategoryId IN (SELECT CategoryId FROM ItemCategory WHERE ParentId = @CategoryId))
      AND (@Zone IS NULL OR ist.Zone = @Zone)
      AND (@Search IS NULL OR i.ItemName LIKE '%' + @Search + '%' OR i.ItemCode LIKE '%' + @Search + '%')
      AND (@PayeeId IS NULL OR i.PreferredVendorId = @PayeeId)
    ORDER BY vc.Sort0, vc.Sort1, i.ItemName;
END
GO
