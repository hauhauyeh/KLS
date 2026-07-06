-- =============================================================================
-- TempSales_GetList -- LIVE BASELINE captured 2026-07-06 (frozen rollback ref).
-- NOTE: the LIVE deployed body (static CTE, LEFT JOIN ItemUnit iu) has DIVERGED
-- from the repo's older save (KLS/SQL/2026-03-31/Update_TempSales_GetList_2E.sql,
-- dynamic SQL, no iu join). THIS file is the true rollback target. Do not edit.
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[TempSales_GetList]
GO

CREATE PROCEDURE [dbo].[TempSales_GetList]
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
            iu.P1 AS ListPrice
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
            NULL AS ListPrice
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
