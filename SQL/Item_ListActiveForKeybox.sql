CREATE PROCEDURE [dbo].[Item_ListActiveForKeybox]
    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH LastOrder AS (
        SELECT
            sd.ItemId,
            s.ShipDate AS LastOrderDate,
            sd.OrdQty AS LastOrderQty,
            sd.Unit AS LastOrderUnit,
            ROW_NUMBER() OVER (PARTITION BY sd.ItemId ORDER BY s.SalesId DESC) AS rn
        FROM SalesDetail sd
        INNER JOIN Sales s ON sd.SalesId = s.SalesId
        WHERE s.ShipId = @PayeeId
    )
    SELECT
        i.ItemId, i.ItemCode, i.ItemName,
        bu.Unit AS BaseUnit, i.LCloseQty, i.Inactive, i.ItemSearchTag,
        lo.LastOrderDate, lo.LastOrderQty, lo.LastOrderUnit
    FROM Item i
    LEFT JOIN ItemUnit bu ON i.ItemId = bu.ItemId AND bu.IsBaseUnit = 1 AND bu.Inactive = 0
    LEFT JOIN LastOrder lo ON i.ItemId = lo.ItemId AND lo.rn = 1
    WHERE i.IsDeleted = 0 AND i.Inactive = 0
    ORDER BY i.ItemName;
END
