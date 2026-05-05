CREATE OR ALTER PROCEDURE [dbo].[Report_Reorder]
(
    @CategoryId INT = NULL,
    @Zone       NVARCHAR(50) = NULL,
    @PayeeId    INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    /*
        2026-05-04 legacy rollback note:
        The previous live version filtered by StorageId and had no vendor filter.
        The current backend now passes Zone and PayeeId instead.

        Old parameter contract:
            @CategoryId INT = NULL,
            @StorageId  INT = NULL
    */

    /*
        2026-05-04 safety note:
        The repo candidate for Report_Reorder also changes the reorder business math.
        This rollout intentionally does NOT adopt those math changes yet.
        This rollout only aligns the procedure signature and filters to match
        the current backend contract, while preserving the live reorder behavior.
    */

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
    ),
    ItemData AS (
        SELECT
            i.ItemId,
            i.ItemCode,
            i.ItemName,
            vc.Cat0,
            vc.Sort0,
            iu.Unit,
            ist.DisplayName AS StorageName,
            (i.LCloseQty - ISNULL(fs.FutureSalesQty, 0)) AS OnHand,
            i.RefillInventory,
            i.ActualSaftyInventory,
            i.Last3M,
            CASE WHEN i.Last3M > 0
                 THEN (i.LCloseQty - ISNULL(fs.FutureSalesQty, 0)) / (i.Last3M / 90.0)
                 ELSE 9999
            END AS DaysOfSupply,
            CASE WHEN i.RefillInventory > (i.LCloseQty - ISNULL(fs.FutureSalesQty, 0))
                 THEN i.RefillInventory - (i.LCloseQty - ISNULL(fs.FutureSalesQty, 0))
                 ELSE 0
            END AS SuggestedQty,
            i.LAvgCost,
            ISNULL(fi.IncomingQty, 0) AS TotalIncoming,
            py.PayeeName AS VendorName,
            i.PreferredVendorId
        FROM Item i
        INNER JOIN ItemUnit iu ON iu.ItemId = i.ItemId AND iu.IsBaseUnit = 1
        LEFT JOIN View_Category vc ON vc.CategoryId = i.CategoryId
        LEFT JOIN ItemStorage ist ON ist.StorageId = i.StorageId
        LEFT JOIN Payee py ON py.PayeeId = i.PreferredVendorId
        LEFT JOIN FutureIncoming fi ON fi.ItemId = i.ItemId
        LEFT JOIN FutureSales fs ON fs.ItemId = i.ItemId
        WHERE i.IsDeleted = 0
          AND i.Inactive = 0
          AND (@CategoryId IS NULL OR i.CategoryId = @CategoryId
               OR i.CategoryId IN (SELECT CategoryId FROM ItemCategory WHERE ParentId = @CategoryId))

          /*
              2026-05-04 retired logic:
              The old live procedure filtered by a single StorageId.
              The newer contract filters by Zone instead.

              AND (@StorageId IS NULL OR i.StorageId = @StorageId)
          */
          AND (@Zone IS NULL OR ist.Zone = @Zone)
          AND (@PayeeId IS NULL OR i.PreferredVendorId = @PayeeId)
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY DaysOfSupply ASC, ItemName) AS AutoId,
        ItemId,
        ItemCode,
        ItemName,
        Cat0,
        Sort0,
        Unit,
        StorageName,
        OnHand,
        RefillInventory,
        ActualSaftyInventory,
        Last3M,
        DaysOfSupply,
        SuggestedQty,
        LAvgCost,
        (SuggestedQty * LAvgCost) AS ReorderValue,
        TotalIncoming,
        VendorName,
        PreferredVendorId
    FROM ItemData
    WHERE OnHand < RefillInventory OR OnHand < ActualSaftyInventory
    ORDER BY DaysOfSupply ASC, ItemName;
END
