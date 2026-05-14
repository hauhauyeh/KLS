-- =====================================================================
-- Report_InventoryStatus
--
-- 2026-05-13 change scope:
--   (a) Add i.Last3M to the projected SELECT so the report can sort by
--       the same Last 3 Months value displayed on the product list,
--       enabling visual order comparison between the two screens.
--   (b) Fix OnHand double-deduction. Item.LCloseQty (maintained by
--       RecalcQAV from the full transaction stream) already includes
--       future-dated SalesDetail rows as if executed, so subtracting
--       fs.FutureSalesQty again over-deducts by exactly that amount.
--       Verified against GusPack ItemId=1: LCloseQty cached at 5530
--       already had the 2026-05-25 sale of 200 baked in; physical
--       on-hand right now is 5730. Old formula returned 5330 (off
--       by 2 x FutureSales = 400). Product list 'Inventory' column
--       uses LCloseQty - (-Item.FutureQty) = LCloseQty + |FutureQty|
--       which gives the physical-now value; the report should match.
--       New formula adds FutureSales back instead of subtracting.
--
--   No filter, join, or sort change.
--   Live baseline at SQL/2026-05-13/Report_InventoryStatus_live_baseline.sql.
-- =====================================================================

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

    /*
        2026-05-04 legacy rollback note:
        The previous live version used the older inventory status contract below.
        That older contract cannot work with the current backend because the backend
        now passes Zone and PayeeId instead of StorageId.

        Old parameter contract:
            @Search       NVARCHAR(100) = NULL,
            @CategoryId   INT = NULL,
            @StorageId    INT = NULL,
            @ShowInactive BIT = 0
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
        -- 2026-05-13 fix: changed '-' to '+'. LCloseQty already deducts
        -- future-dated sales via RecalcQAV; subtracting again double-counts.
        -- Old: (i.LCloseQty - ISNULL(fs.FutureSalesQty, 0)) AS OnHand,
        (i.LCloseQty + ISNULL(fs.FutureSalesQty, 0)) AS OnHand,
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
        i.Last3M,   -- 2026-05-13 added (Round): expose cached 3-month rollup for sort-compare with product list
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

      /*
          2026-05-04 retired logic:
          The old live procedure filtered by a single StorageId.
          That logic is being retired because the current backend now passes Zone.

          AND (@StorageId IS NULL OR i.StorageId = @StorageId)
      */
      AND (@Zone IS NULL OR ist.Zone = @Zone)

      AND (@Search IS NULL OR i.ItemName LIKE '%' + @Search + '%' OR i.ItemCode LIKE '%' + @Search + '%')
      AND (@PayeeId IS NULL OR i.PreferredVendorId = @PayeeId)
    ORDER BY vc.Sort0, vc.Sort1, i.ItemName;
END

