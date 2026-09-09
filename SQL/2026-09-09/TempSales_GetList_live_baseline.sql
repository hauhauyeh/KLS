
CREATE   PROCEDURE [dbo].[TempSales_GetList]
    @EmpId INT,
    @PayeeId INT,
    @SalesId INT,
    @SortField NVARCHAR(50),
	@SortOrder NVARCHAR(10),
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH FilteredTempSales AS
    (
        SELECT *
        FROM TempSales
        WHERE EmpId = @EmpId
          AND SalesId = @SalesId
          AND PayeeId = @PayeeId
          AND (@Id IS NULL OR TempSalesId = @Id)
          AND (ChangeStatus IS NULL OR ChangeStatus <> 'D')
    ),
    TempSalesList AS
    (
        SELECT
            t.*,
            ps.ShipDate AS ParentShipDate,
            i.ItemName,
            i.ItemCode,
            i.CaseWeight,
            i.PackSize,
            i.LCloseQty,
            bu.Unit AS BaseUnit,
            iu.P1 AS ListPrice,
            -- 2026-07-06: MultipleToBase from ItemUnit (existing iu join) -- numerator for combine-up.
            ISNULL(iu.MultipleToBase, 1) AS MultipleToBase
        FROM FilteredTempSales t
        INNER JOIN Item i
            ON t.ItemId = i.ItemId
        LEFT JOIN ItemUnit bu
            ON i.ItemId = bu.ItemId
           AND bu.IsBaseUnit = 1
           AND bu.Inactive = 0
        LEFT JOIN ItemUnit iu
            ON t.ItemUnitId = iu.ItemUnitId
        LEFT JOIN Sales ps
            ON t.ParentSalesNumber = ps.SalesNumber
        WHERE t.ItemId IS NOT NULL

        UNION ALL

        SELECT
            t.*,
            ps.ShipDate AS ParentShipDate,
            a.AccountName AS ItemName,
            a.AccountCode AS ItemCode,
            NULL AS CaseWeight,
            NULL AS PackSize,
            NULL AS LCloseQty,
            NULL AS BaseUnit,
            NULL AS ListPrice,
            -- 2026-07-06: account lines carry no ratio -> constant 1.
            1 AS MultipleToBase
        FROM FilteredTempSales t
        INNER JOIN Account a
            ON t.AccountId = a.AccountId
        LEFT JOIN Sales ps
            ON t.ParentSalesNumber = ps.SalesNumber
        WHERE t.AccountId IS NOT NULL
    )
    SELECT *
    FROM TempSalesList
    ORDER BY
        ISNULL(DisplaySort, LineId) DESC,
        CASE WHEN CartLineType = 'MAIN' THEN 0 ELSE 1 END ASC,
        LineId ASC;
END
