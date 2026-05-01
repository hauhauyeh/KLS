CREATE OR ALTER PROCEDURE [dbo].[Scheduler_UpdateItem]
AS
BEGIN

    SET NOCOUNT ON;

    -- ============================================================
    -- Date Variables (computed once, reused everywhere)
    -- ============================================================
    DECLARE @GetDate DATE = CAST(GETDATE() AS DATE);
    DECLARE @Date3MonthAgo DATE = DATEADD(MONTH, -3, @GetDate);
    DECLARE @Date30DaysAgo DATE = DATEADD(DAY, -30, @GetDate);
    DECLARE @YTDStart DATE = DATEFROMPARTS(YEAR(@GetDate), 1, 1);
    DECLARE @M6Start DATE = DATEFROMPARTS(YEAR(DATEADD(MONTH, -6, @GetDate)), MONTH(DATEADD(MONTH, -6, @GetDate)), 1);

    DECLARE @M0 VARCHAR(7) = FORMAT(DATEADD(MONTH, 0, @GetDate), 'yyyy-MM');
    DECLARE @M1 VARCHAR(7) = FORMAT(DATEADD(MONTH, -1, @GetDate), 'yyyy-MM');
    DECLARE @M2 VARCHAR(7) = FORMAT(DATEADD(MONTH, -2, @GetDate), 'yyyy-MM');
    DECLARE @M3 VARCHAR(7) = FORMAT(DATEADD(MONTH, -3, @GetDate), 'yyyy-MM');
    DECLARE @M4 VARCHAR(7) = FORMAT(DATEADD(MONTH, -4, @GetDate), 'yyyy-MM');
    DECLARE @M5 VARCHAR(7) = FORMAT(DATEADD(MONTH, -5, @GetDate), 'yyyy-MM');
    DECLARE @M6 VARCHAR(7) = FORMAT(DATEADD(MONTH, -6, @GetDate), 'yyyy-MM');

    DECLARE @InvAccountId INT;
    DECLARE @YTDTotal DECIMAL(18, 2);

    SELECT @InvAccountId = AccountId FROM Account WHERE AccountCode = '@INV';

    -- ============================================================
    -- Reset Item Columns (single pass, no WHERE needed)
    -- ============================================================
    UPDATE Item
    SET
        SaftyInventory = 0,
        Last3M = NULL,
        IsHighlighted = 0,
        YTD = NULL,
        YTDSalesPercent = NULL;

    -- ============================================================
    -- Temp Table: Pre-aggregate TransactionJournalDetail once
    -- Covers: 6-month window (also covers Last3M and PreferredVendor ranges)
    -- Avoids scanning TransactionJournal/Detail multiple times
    -- ============================================================
    CREATE TABLE #TxAgg
    (
        ItemId INT NOT NULL,
        PayeeId INT NULL,
        TxDate DATE NOT NULL,
        ShipMonth VARCHAR(7) NOT NULL,
        SourceDocType VARCHAR(50) NOT NULL,
        Qty DECIMAL(18, 4) NOT NULL,
        SalesValue DECIMAL(18, 4) NULL
    );

    INSERT INTO #TxAgg (ItemId, PayeeId, TxDate, ShipMonth, SourceDocType, Qty, SalesValue)
    SELECT
        td.ItemId,
        td.PayeeId,
        t.TxDate,
        CONVERT(VARCHAR(7), t.TxDate, 126) AS ShipMonth,
        t.SourceDocType,
        td.Qty,
        ISNULL(td.Qty, 0) * ISNULL(td.Price, 0) AS SalesValue
    FROM TransactionJournal t
    INNER JOIN TransactionJournalDetail td ON td.TxId = t.TxId
    INNER JOIN Item i ON i.ItemId = td.ItemId
    WHERE td.AccountId = @InvAccountId
      AND t.TxDate >= CASE WHEN @YTDStart < @M6Start THEN @YTDStart ELSE @M6Start END
      AND td.ItemId IS NOT NULL;

    CREATE NONCLUSTERED INDEX IX_TxAgg_ItemId ON #TxAgg (ItemId);
    CREATE NONCLUSTERED INDEX IX_TxAgg_DocType_Date ON #TxAgg (SourceDocType, TxDate) INCLUDE (ItemId, PayeeId, Qty, SalesValue);

    -- ============================================================
    -- Update Safety Inventory (last 30 days shipped qty)
    -- ============================================================
    UPDATE i
    SET i.SaftyInventory = ISNULL(x.Last30DayQty, 0)
    FROM Item i
    LEFT JOIN
    (
        SELECT SD.ItemId, SUM(SD.BaseShipQty) AS Last30DayQty
        FROM SalesDetail SD
        INNER JOIN Sales S ON S.SalesId = SD.SalesId
        WHERE S.ShipDate >= @Date30DaysAgo
        GROUP BY SD.ItemId
    ) x ON x.ItemId = i.ItemId;

    -- ============================================================
    -- Update Today Opening Inventory (latest closing qty per item)
    -- ============================================================
    WITH cteTodayInv AS
    (
        SELECT
            td.ItemId,
            td.ClosingQty,
            ROW_NUMBER() OVER (PARTITION BY td.ItemId ORDER BY t.TxDate DESC, t.SourceDocOrder DESC, td.TxDetailId DESC) AS RowNum
        FROM TransactionJournal t
        INNER JOIN TransactionJournalDetail td ON td.TxId = t.TxId
        WHERE td.AccountId = @InvAccountId
          AND t.TxDate < @GetDate
    )
    UPDATE i
    SET i.TodayOpenInventory = c.ClosingQty
    FROM cteTodayInv c
    INNER JOIN Item i ON i.ItemId = c.ItemId
    WHERE c.RowNum = 1;

    -- ============================================================
    -- Update Last 6 Month Sales Quantities (M0-M6)
    -- Single pass over #TxAgg with conditional aggregation
    -- ============================================================
    WITH ctePivot AS
    (
        SELECT
            ItemId,
            SUM(CASE WHEN ShipMonth = @M0 THEN Qty ELSE 0 END) AS M0,
            SUM(CASE WHEN ShipMonth = @M1 THEN Qty ELSE 0 END) AS M1,
            SUM(CASE WHEN ShipMonth = @M2 THEN Qty ELSE 0 END) AS M2,
            SUM(CASE WHEN ShipMonth = @M3 THEN Qty ELSE 0 END) AS M3,
            SUM(CASE WHEN ShipMonth = @M4 THEN Qty ELSE 0 END) AS M4,
            SUM(CASE WHEN ShipMonth = @M5 THEN Qty ELSE 0 END) AS M5,
            SUM(CASE WHEN ShipMonth = @M6 THEN Qty ELSE 0 END) AS M6
        FROM #TxAgg
        WHERE SourceDocType = 'Sales'
        GROUP BY ItemId
    )
    UPDATE i
    SET
        i.M0 = c.M0,
        i.M1 = c.M1,
        i.M2 = c.M2,
        i.M3 = c.M3,
        i.M4 = c.M4,
        i.M5 = c.M5,
        i.M6 = c.M6
    FROM Item i
    INNER JOIN ctePivot c ON c.ItemId = i.ItemId;

    -- ============================================================
    -- Update Last 3 Month Total Sales Value
    -- ============================================================
    WITH cteLast3M AS
    (
        SELECT ItemId, SUM(SalesValue) AS TotalQty
        FROM #TxAgg
        WHERE SourceDocType = 'Sales'
          AND TxDate >= @Date3MonthAgo
        GROUP BY ItemId
    )
    UPDATE i
    SET i.Last3M = c.TotalQty
    FROM Item i
    INNER JOIN cteLast3M c ON c.ItemId = i.ItemId;

    -- ============================================================
    -- Fallback for newly arrived items:
    -- if an item has no sales in the last 3 months but it arrived within
    -- the same 90-day window, force Last3M = 1 so keybox cache mode can
    -- still preload it for ordering.
    -- ============================================================
    ;WITH RecentArrival AS
    (
        SELECT DISTINCT pd.ItemId
        FROM PurchaseDetail pd
        INNER JOIN Purchase p ON p.PurchaseId = pd.PurchaseId
        WHERE p.ArrivalDate >= @Date3MonthAgo
          AND pd.ItemId IS NOT NULL
    )
    UPDATE i
    SET i.Last3M = 1
    FROM Item i
    INNER JOIN RecentArrival ra ON ra.ItemId = i.ItemId
    WHERE ISNULL(i.Last3M, 0) = 0;

    -- ============================================================
    -- Highlight Top 200 Items by Last 3 Months
    -- ============================================================
    WITH cteTop200 AS
    (
        SELECT TOP (200) ItemId, IsHighlighted
        FROM Item
        ORDER BY Last3M DESC
    )
    UPDATE cteTop200
    SET IsHighlighted = 1;

    -- ============================================================
    -- Update YTD Quantity and Sales
    -- ============================================================
    WITH cteYTD AS
    (
        SELECT
            ItemId,
            SUM(Qty) AS TotalQty,
            SUM(SalesValue) AS TotalSales
        FROM #TxAgg
        WHERE SourceDocType = 'Sales'
          AND TxDate >= @YTDStart
        GROUP BY ItemId
    )
    UPDATE i
    SET
        i.YTD = c.TotalQty,
        i.YTDSalesPercent = c.TotalSales
    FROM Item i
    INNER JOIN cteYTD c ON c.ItemId = i.ItemId;

    -- Normalize YTDSalesPercent to fraction of total
    SELECT @YTDTotal = SUM(YTDSalesPercent) FROM Item;

    UPDATE Item
    SET YTDSalesPercent = CASE WHEN @YTDTotal <> 0 THEN YTDSalesPercent / @YTDTotal ELSE 0 END;

    -- ============================================================
    -- Update Preferred Vendor (top supplier by qty, last 3 months)
    -- ============================================================
    WITH ctePreferredVendor AS
    (
        SELECT
            ItemId,
            PayeeId,
            ROW_NUMBER() OVER (PARTITION BY ItemId ORDER BY SUM(Qty) DESC) AS RN
        FROM #TxAgg
        WHERE SourceDocType = 'Purchase'
          AND TxDate >= @Date3MonthAgo
        GROUP BY ItemId, PayeeId
    )
    UPDATE i
    SET i.PreferredVendorId = c.PayeeId
    FROM ctePreferredVendor c
    INNER JOIN Item i ON i.ItemId = c.ItemId
    WHERE c.RN = 1;

    -- ============================================================
    -- Cleanup
    -- ============================================================
    DROP TABLE IF EXISTS #TxAgg;

END
