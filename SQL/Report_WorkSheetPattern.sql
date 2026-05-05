SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
Reconstructed working version of dbo.Report_WorkSheetPattern
Built on 2026-05-04 from the legacy worksheet pattern contract and the current KLS_2026 schema.

Legacy contract that this procedure preserves:
- @Search
- @PayeeId
- @Filterby
- @Category
- @Inactive

Important note:
- The legacy manager grouped the returned rows by Vendor or Storage.
- That grouping happened in application code, not inside the stored procedure.
- This procedure therefore accepts @Filterby for contract compatibility, but does not branch on it.
*/

CREATE OR ALTER PROCEDURE [dbo].[Report_WorkSheetPattern]
(
    @Search   NVARCHAR(100) = NULL,
    @PayeeId  INT = NULL,
    @Filterby NVARCHAR(50) = NULL,
    @Category NVARCHAR(50) = NULL,
    @Inactive BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;

    /*
    Convert the legacy string category parameter into the current numeric category filter.
    Legacy callers passed Category as a string in the report request model.
    */
    DECLARE @CategoryId INT = TRY_CONVERT(INT, @Category);

    /*
    Return one worksheet row per item.
    The current schema already stores:
    - current on hand quantity in Item.LCloseQty
    - future committed change in Item.FutureQty
    - trailing month demand in Item.M1 through Item.M6
    - preferred vendor in Item.PreferredVendorId
    - storage display name in ItemStorage.DisplayName
    */
    SELECT
        ROW_NUMBER() OVER (ORDER BY vc.Sort0, vc.Sort1, i.ItemName) AS Id,
        i.ItemCode,
        i.ItemName AS ItemDesc1,
        CAST(NULL AS NVARCHAR(200)) AS ItemDescX1,
        vc.Cat0 AS Category0,
        iu.Unit,
        i.LCloseQty AS CloQty,
        i.FutureQty AS FutureChg,
        ist.DisplayName AS Storage,
        i.PackSize,
        i.Last3M AS MostOrdered,
        py.PayeeName,
        i.M1,
        i.M2,
        i.M3,
        i.M4,
        i.M5,
        i.M6
    FROM dbo.Item i
    INNER JOIN dbo.ItemUnit iu
        ON iu.ItemId = i.ItemId
       AND iu.IsBaseUnit = 1
    LEFT JOIN dbo.View_Category vc
        ON vc.CategoryId = i.CategoryId
    LEFT JOIN dbo.ItemStorage ist
        ON ist.StorageId = i.StorageId
    LEFT JOIN dbo.Payee py
        ON py.PayeeId = i.PreferredVendorId
    WHERE i.IsDeleted = 0
      AND (@Inactive = 1 OR i.Inactive = 0)
      AND (
            @Search IS NULL
            OR i.ItemName LIKE '%' + @Search + '%'
            OR i.ItemCode LIKE '%' + @Search + '%'
          )
      AND (
            @PayeeId IS NULL
            OR i.PreferredVendorId = @PayeeId
          )
      AND (
            @CategoryId IS NULL
            OR i.CategoryId = @CategoryId
            OR i.CategoryId IN (
                SELECT ic.CategoryId
                FROM dbo.ItemCategory ic
                WHERE ic.ParentId = @CategoryId
            )
          )
    ORDER BY vc.Sort0, vc.Sort1, i.ItemName;
END
GO
