CREATE OR ALTER PROCEDURE [dbo].[Item_ListActiveForKeybox]
    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    /*
    Baseline before candidate-item confinement:

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
            i.LCloseQty,
            i.Inactive,
            i.ItemSearchTag,
            i.Last3M
        FROM Item i
        WHERE i.IsDeleted = 0
          AND i.Inactive = 0
          AND ISNULL(i.Last3M, 0) > 0
    ),
    LastOrder AS (
        SELECT
            sd.ItemId,
            s.ShipDate AS LastOrderDate,
            sd.OrdQty AS LastOrderQty,
            sd.Unit AS LastOrderUnit,
            ROW_NUMBER() OVER (PARTITION BY sd.ItemId ORDER BY s.SalesId DESC) AS rn
        FROM CandidateItems ci
        INNER JOIN SalesDetail sd ON ci.ItemId = sd.ItemId
        INNER JOIN Sales s ON sd.SalesId = s.SalesId
        WHERE s.ShipId = @PayeeId
    )
    SELECT TOP (500)
        ci.ItemId, ci.ItemCode, ci.ItemName,
        bu.Unit AS BaseUnit, ci.LCloseQty, ci.Inactive, ci.ItemSearchTag,
        lo.LastOrderDate, lo.LastOrderQty, lo.LastOrderUnit
    FROM CandidateItems ci
    LEFT JOIN ItemUnit bu ON ci.ItemId = bu.ItemId AND bu.IsBaseUnit = 1 AND bu.Inactive = 0
    LEFT JOIN LastOrder lo ON ci.ItemId = lo.ItemId AND lo.rn = 1
    ORDER BY ci.Last3M DESC;
END
