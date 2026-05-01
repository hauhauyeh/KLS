-- Deploy: Create Report_SalesByInvoice SP
-- One row per invoice, with item-only profitability based on inventory item lines.

CREATE OR ALTER PROCEDURE [dbo].[Report_SalesByInvoice]
    @StartDate DATE,
    @EndDate DATE,
    @SalesRep INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsSingleDay BIT = CASE WHEN @StartDate = @EndDate THEN 1 ELSE 0 END;

    ;WITH InvoiceScope AS
    (
        SELECT
            s.SalesId,
            s.SalesNumber,
            s.ParentSalesNumber,
            s.DocType,
            s.ShipDate,
            s.ShipRoute,
            s.ShipId,
            s.SalesRepId,
            s.SalesTotal,
            COALESCE(s.SalesMarginOrderPercent, s.SalesMarginPercent, 0) AS MarginPercent
        FROM Sales s
        WHERE s.ShipDate BETWEEN @StartDate AND @EndDate
          AND s.SalesRepId = CASE WHEN @SalesRep IS NOT NULL THEN @SalesRep ELSE s.SalesRepId END
    ),
    InventoryLineTotals AS
    (
        SELECT
            sd.SalesId,
            SUM(sd.ExtTotal) AS CountableTotal
        FROM SalesDetail sd
        INNER JOIN Item i ON i.ItemId = sd.ItemId
        INNER JOIN InvoiceScope s ON s.SalesId = sd.SalesId
        WHERE sd.LineType = 'I'
          AND i.ItemType = 'Inventory'
        GROUP BY sd.SalesId
    )
    SELECT
        CAST(ROW_NUMBER() OVER
        (
            ORDER BY
                CONVERT(NVARCHAR(10), s.ShipDate, 23),
                p.PayeeName,
                s.SalesNumber
        ) AS INT) AS Id,
        s.ShipDate,
        s.ShipRoute,
        s.SalesNumber,
        s.ParentSalesNumber,
        s.DocType,
        s.ShipId,
        p.PayeeName,
        s.SalesRepId,
        CAST(s.SalesTotal AS DECIMAL(18,2)) AS InvoiceTotal,
        CAST(ISNULL(i.CountableTotal, 0) AS DECIMAL(18,2)) AS CountableTotal,
        CAST(ISNULL(i.CountableTotal, 0) * (1 - s.MarginPercent) AS DECIMAL(18,2)) AS CostTotal,
        CAST(ISNULL(i.CountableTotal, 0) * s.MarginPercent AS DECIMAL(18,2)) AS MarginAmount,
        CAST(CASE
            WHEN ISNULL(i.CountableTotal, 0) = 0 THEN 0
            ELSE s.MarginPercent
        END AS DECIMAL(18,4)) AS MarginPercent
    FROM InvoiceScope s
    LEFT JOIN InventoryLineTotals i ON i.SalesId = s.SalesId
    LEFT JOIN Payee p ON p.PayeeId = s.ShipId
    ORDER BY
        CONVERT(NVARCHAR(10), s.ShipDate, 23),
        p.PayeeName,
        s.SalesNumber;
END
