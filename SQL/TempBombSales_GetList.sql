CREATE   PROCEDURE [dbo].[TempBombSales_GetList]
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
            -- 2026-05-01 23:21 ET: add base load-route inputs so Bomb Sales can
            -- transition to the same display rule used by Order Manager.
            s.RouteOrder,
            s.IsLoadSeparate,
            -- 2026-05-01 23:45 ET: legacy computed LoadRoute output commented out
            -- after Bomb Sales list and report moved to base-column route display.
            -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) AS LoadRoute,
            s.StageId,
            s.IsLocked
        FROM TempBombSales t
        INNER JOIN Item i ON t.ItemId = i.ItemId
        INNER JOIN Payee p ON t.PayeeId = p.PayeeId
        INNER JOIN Sales s ON s.SalesId = t.SalesId
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
                WHEN dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) = s.ShipRoute THEN 0
                ELSE 1
            END,
            TRY_CAST(REPLACE(dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate), s.ShipRoute, '') AS INT) DESC,
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
            -- 2026-05-01 23:21 ET: add base load-route inputs so Bomb Sales can
            -- transition to the same display rule used by Order Manager.
            s.RouteOrder,
            s.IsLoadSeparate,
            -- 2026-05-01 23:45 ET: legacy computed LoadRoute output commented out
            -- after Bomb Sales list and report moved to base-column route display.
            -- dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) AS LoadRoute,
            s.StageId,
            s.IsLocked
        FROM TempBombSales t
        INNER JOIN Item i ON t.ItemId = i.ItemId
        INNER JOIN Payee p ON t.PayeeId = p.PayeeId
        INNER JOIN Sales s ON s.SalesId = t.SalesId
        WHERE t.EmpId = @EmpId
          AND (@TempId IS NULL OR t.TempBombId = @TempId)
        ORDER BY
            s.ShipDate DESC,
            s.ShipRoute,
            CASE
                WHEN dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate) = s.ShipRoute THEN 0
                ELSE 1
            END,
            TRY_CAST(REPLACE(dbo.Fn_Calc_EffectiveLoadRoute(s.ShipRoute, s.RouteOrder, s.IsLoadSeparate), s.ShipRoute, '') AS INT) DESC,
            p.PayeeName,
            s.SalesNumber;
    END
END;
