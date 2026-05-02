-- Deploy: Add 'all' filter to ItemQuote_GetTargetPrice
EXEC sp_rename 'ItemQuote_GetTargetPrice', 'ItemQuote_GetTargetPrice_prev';
GO

CREATE PROCEDURE [dbo].[ItemQuote_GetTargetPrice]
    @ItemId INT,
    @Filterby NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Q AS
    (
        SELECT
            I.ItemQuoteId,
            i.ItemUnitId,
            iu.Unit,
            I.MarkupPercent,
            I.TargetPrice,
            i.IsFixed,
            P.PayeeName,
            C.BaseMarkup,
            iu.P1,
            c.IsBaseToRecentCost,
            iu.RecentCost,
            P.Payee30Volume
        FROM ItemQuote AS I
        INNER JOIN Payee AS P ON I.PayeeId = P.PayeeId
        INNER JOIN Customer AS C ON C.PayeeId = p.PayeeId
        INNER JOIN ItemUnit AS IU ON IU.ItemUnitId = i.ItemUnitId
        WHERE I.ItemId = @ItemId
    )
    SELECT *
    FROM Q
    WHERE
        (@Filterby = 'all')
        OR
        (@Filterby = 'NULL' AND MarkupPercent IS NULL)
        OR
        (@Filterby = 'WITHIN5' AND MarkupPercent IS NOT NULL AND ABS(MarkupPercent) <= 0.05)
        OR
        (@Filterby = 'outside5' AND MarkupPercent IS NOT NULL AND ABS(MarkupPercent) > 0.05)
        OR
        (@Filterby = 'fixed' AND IsFixed = 1)
    ORDER BY
        MarkupPercent DESC,
        Payee30Volume DESC,
        PayeeName;
END
GO
