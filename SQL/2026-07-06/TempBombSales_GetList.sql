-- =============================================================================
-- TempBombSales_GetList -- deploy (CREATE OR ALTER). Working file per SP workflow.
-- 2026-07-06: add MultipleToBase to the result so BombSalesItem.OrdCases computes
--   OrdQty * MultipleToBase / FactorToBase (combine-up numerator). KEEP t.* (temp snapshot
--   FactorToBase denominator preserved -- edit fidelity). No ItemUnit join existed, so ADD
--   LEFT JOIN ItemUnit iu ON iu.ItemUnitId = t.ItemUnitId to BOTH IF/ELSE branches and add
--   ISNULL(iu.MultipleToBase,1). No account block (all rows INNER JOIN Item). No Temp* schema
--   change. Only FromSqlRaw<BombSalesItem> producer (repo :29); Inject/Save are ExecuteSqlRaw
--   writes. Identity today (all MultipleToBase=1). Last Phase-C reader.
-- Baseline: KLS/SQL/2026-07-06/TempBombSales_GetList_live_baseline.sql
-- =============================================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[TempBombSales_GetList]
    @EmpId      INT,
    @CheckAgain BIT,
    @TempId     INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @CheckAgain = 1
    BEGIN
        SELECT TOP (500)
            t.*,
            p.PayeeName,
            i.ItemName,
            i.ItemCode,
            s.ShipDate,
            s.ShipRoute,
            s.RouteOrder,
            s.IsLoadSeparate,
            s.StageId,
            s.IsLocked,
            -- 2026-07-06: MultipleToBase from ItemUnit (added iu join) -- numerator for combine-up.
            ISNULL(iu.MultipleToBase, 1) AS MultipleToBase
        FROM TempBombSales t
        INNER JOIN Item i ON t.ItemId = i.ItemId
        INNER JOIN Payee p ON t.PayeeId = p.PayeeId
        INNER JOIN Sales s ON s.SalesId = t.SalesId
        LEFT JOIN ItemUnit iu ON iu.ItemUnitId = t.ItemUnitId
        WHERE t.EmpId = @EmpId
          AND (
                t.UnitPrice = 0
                OR (t.Unit = 'lb' AND t.ShipQty = 1 AND t.IsUserOverWrite = 0)
                OR (t.Unit = 'lbs' AND t.ShipQty >= 1 AND t.IsUserOverWrite = 0)
                OR (t.Unit = 'lbs' AND t.ShipQty = 1 AND t.IsUserOverWrite = 1)
              )
        ORDER BY
            s.ShipDate DESC,
            s.ShipRoute,
            CASE
                WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND ISNULL(s.RouteOrder, 0) > 0 THEN 1
                ELSE 0
            END,
            CASE
                WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND ISNULL(s.RouteOrder, 0) > 0 THEN s.RouteOrder
                ELSE 0
            END DESC,
            p.PayeeName,
            s.SalesNumber;
    END
    ELSE
    BEGIN
        SELECT TOP (500)
            t.*,
            p.PayeeName,
            i.ItemName,
            i.ItemCode,
            s.ShipDate,
            s.ShipRoute,
            s.RouteOrder,
            s.IsLoadSeparate,
            s.StageId,
            s.IsLocked,
            -- 2026-07-06: MultipleToBase from ItemUnit (added iu join) -- numerator for combine-up.
            ISNULL(iu.MultipleToBase, 1) AS MultipleToBase
        FROM TempBombSales t
        INNER JOIN Item i ON t.ItemId = i.ItemId
        INNER JOIN Payee p ON t.PayeeId = p.PayeeId
        INNER JOIN Sales s ON s.SalesId = t.SalesId
        LEFT JOIN ItemUnit iu ON iu.ItemUnitId = t.ItemUnitId
        WHERE t.EmpId = @EmpId
          AND (@TempId IS NULL OR t.TempBombId = @TempId)
        ORDER BY
            s.ShipDate DESC,
            s.ShipRoute,
            CASE
                WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND ISNULL(s.RouteOrder, 0) > 0 THEN 1
                ELSE 0
            END,
            CASE
                WHEN ISNULL(s.IsLoadSeparate, 0) = 1 AND ISNULL(s.RouteOrder, 0) > 0 THEN s.RouteOrder
                ELSE 0
            END DESC,
            p.PayeeName,
            s.SalesNumber;
    END
END;
