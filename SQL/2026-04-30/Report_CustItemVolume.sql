-- Report_CustItemVolume — Last 6 months item sales volume for a customer
-- Adapted from legacy SP for KLS_Latest schema
CREATE PROCEDURE [dbo].[Report_CustItemVolume]
    @PayeeId INT,
    @Sortby NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @M1 VARCHAR(7) = CONVERT(VARCHAR(7), GETDATE(), 126);
    DECLARE @M2 VARCHAR(7) = CONVERT(VARCHAR(7), DATEADD(MONTH, -1, GETDATE()), 126);
    DECLARE @M3 VARCHAR(7) = CONVERT(VARCHAR(7), DATEADD(MONTH, -2, GETDATE()), 126);
    DECLARE @M4 VARCHAR(7) = CONVERT(VARCHAR(7), DATEADD(MONTH, -3, GETDATE()), 126);
    DECLARE @M5 VARCHAR(7) = CONVERT(VARCHAR(7), DATEADD(MONTH, -4, GETDATE()), 126);
    DECLARE @M6 VARCHAR(7) = CONVERT(VARCHAR(7), DATEADD(MONTH, -5, GETDATE()), 126);

    ;WITH cte AS (
        SELECT
            i.ItemCode,
            i.ItemName,
            iu.Unit,
            v.Cat0,
            v.Cat1,
            v.Sort0,
            v.Sort1,
            CONVERT(VARCHAR(7), s.ShipDate, 126) AS ShipMonth,
            SUM(sd.BaseShipQty) AS ShipQty
        FROM dbo.Sales AS s
        INNER JOIN dbo.SalesDetail AS sd ON s.SalesId = sd.SalesId
        INNER JOIN dbo.Item AS i ON i.ItemId = sd.ItemId
        LEFT JOIN dbo.ItemUnit AS iu ON iu.ItemId = i.ItemId AND iu.IsBaseUnit = 1
        LEFT JOIN dbo.View_Category AS v ON v.CategoryId = i.CategoryId
        WHERE s.ShipId = @PayeeId
          AND CONVERT(VARCHAR(7), s.ShipDate, 126) IN (@M1, @M2, @M3, @M4, @M5, @M6)
        GROUP BY i.ItemCode, i.ItemName, iu.Unit, v.Cat0, v.Cat1, v.Sort0, v.Sort1,
                 CONVERT(VARCHAR(7), s.ShipDate, 126)
    )
    SELECT ItemCode, ItemName, Unit, Cat0, Cat1,
           [M1], [M2], [M3], [M4], [M5], [M6]
    FROM (
        SELECT ItemCode, ItemName, Unit, Cat0, Cat1, Sort0, Sort1, ShipQty,
            CASE
                WHEN ShipMonth = @M1 THEN 'M1'
                WHEN ShipMonth = @M2 THEN 'M2'
                WHEN ShipMonth = @M3 THEN 'M3'
                WHEN ShipMonth = @M4 THEN 'M4'
                WHEN ShipMonth = @M5 THEN 'M5'
                WHEN ShipMonth = @M6 THEN 'M6'
            END AS ShipMonth
        FROM cte
    ) AS src
    PIVOT (
        SUM(ShipQty) FOR ShipMonth IN ([M1], [M2], [M3], [M4], [M5], [M6])
    ) AS pvt
    ORDER BY
        CASE WHEN @Sortby = 'qty' THEN NULL ELSE Sort0 END,
        CASE WHEN @Sortby = 'qty' THEN NULL ELSE Sort1 END,
        CASE WHEN @Sortby = 'qty' THEN M1 END DESC,
        ItemName;
END
