CREATE PROCEDURE [dbo].[Report_InventoryMovement]
(
    @CategoryId INT = NULL,
    @Zone       NVARCHAR(50) = NULL,
    @ShowExpiry BIT = 0,
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
        ROW_NUMBER() OVER (ORDER BY i.Last3M DESC, i.ItemName) AS AutoId,
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        vc.Cat0,
        vc.Sort0,
        ist.DisplayName AS StorageName,
        iu.Unit,
        (i.LCloseQty - ISNULL(fs.FutureSalesQty, 0)) AS OnHand,
        i.M0,
        i.M1,
        i.M2,
        i.M3,
        i.Last3M,
        i.YTD,
        i.YTDSalesPercent,
        i.ExpiryDate,
        DATEDIFF(DAY,
            (SELECT MAX(s.ShipDate)
             FROM SalesDetail sd
             INNER JOIN Sales s ON s.SalesId = sd.SalesId
             WHERE sd.ItemId = i.ItemId AND s.ShipDate IS NOT NULL),
            GETDATE()
        ) AS DaysSinceLastSold,
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
      AND (@ShowExpiry = 0 OR i.ExpiryDate IS NOT NULL)
      AND (@PayeeId IS NULL OR i.PreferredVendorId = @PayeeId)
    ORDER BY i.Last3M DESC, i.ItemName;
END
GO
