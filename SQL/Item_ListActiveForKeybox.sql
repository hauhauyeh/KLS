    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    /*
    Baseline before candidate-item confinement:

    ;WITH LastOrder AS (
        SELECT
            s.SalesId,
            s.ShipDate
        FROM Sales s
        WHERE s.ShipId = @PayeeId
    ),
    LastOrder AS (
        SELECT
            sd.ItemId,
            sd.OrdQty AS LastOrderQty,
            sd.Unit AS LastOrderUnit,
    )
    SELECT TOP (500)
        i.ItemId, i.ItemCode, i.ItemName,
        bu.Unit AS BaseUnit, i.LCloseQty, i.Inactive, i.ItemSearchTag,
        lo.LastOrderDate, lo.LastOrderQty, lo.LastOrderUnit
    FROM Item i
    LEFT JOIN ItemUnit bu ON i.ItemId = bu.ItemId AND bu.IsBaseUnit = 1 AND bu.Inactive = 0
    LEFT JOIN LastOrder lo ON i.ItemId = lo.ItemId AND lo.rn = 1
    WHERE i.IsDeleted = 0 AND i.Inactive = 0
    ORDER BY i.Last3M DESC;
    */

    ;WITH CandidateItems AS (
        SELECT
            i.ItemId,
            i.ItemCode,
            i.ItemName,
        bu.Unit AS BaseUnit,
            i.LCloseQty,
            i.Inactive,
            i.ItemSearchTag,
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
END
GO
