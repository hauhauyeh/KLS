SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Item_ListActiveForKeybox]
    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH CustomerSales AS (
        SELECT
            s.SalesId,
            s.ShipDate
        FROM Sales s
        WHERE s.ShipId = @PayeeId
    ),
    LastOrder AS (
        SELECT
            sd.ItemId,
            cs.ShipDate AS LastOrderDate,
            sd.OrdQty AS LastOrderQty,
            sd.Unit AS LastOrderUnit,
            ROW_NUMBER() OVER (
                PARTITION BY sd.ItemId
                ORDER BY cs.SalesId DESC
            ) AS rn
        FROM CustomerSales cs
        INNER JOIN SalesDetail sd ON cs.SalesId = sd.SalesId
    )
    SELECT
        i.ItemId,
        i.ItemCode,
        i.ItemName,
        bu.Unit AS BaseUnit,
        i.LCloseQty,
        i.Inactive,
        i.ItemSearchTag,
        lo.LastOrderDate,
        lo.LastOrderQty,
        lo.LastOrderUnit
    FROM Item i
    LEFT JOIN ItemUnit bu
        ON i.ItemId = bu.ItemId
       AND bu.IsBaseUnit = 1
       AND bu.Inactive = 0
    LEFT JOIN LastOrder lo
        ON i.ItemId = lo.ItemId
       AND lo.rn = 1
    WHERE i.IsDeleted = 0
      AND i.Inactive = 0
    ORDER BY i.Last3M DESC;
END
GO
