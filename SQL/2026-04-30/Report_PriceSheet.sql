-- Report_PriceSheet — Returns pricesheet items for a customer
-- Uses Fn_GetPrice for pricing, Sort0/Sort1/Sort2 for category ordering
CREATE PROCEDURE [dbo].[Report_PriceSheet]
    @PayeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @HasOwnList BIT = 0;
    DECLARE @ShareQuoteId INT = NULL;
    DECLARE @EffectivePayeeId INT;

    SELECT
        @HasOwnList   = ISNULL(c.HasOwnList, 0),
        @ShareQuoteId = c.ShareQuoteId
    FROM dbo.Customer c
    WHERE c.PayeeId = @PayeeId;

    SET @EffectivePayeeId =
    CASE
        WHEN @HasOwnList = 1 THEN @PayeeId
        ELSE @ShareQuoteId
    END;

    SELECT
        i.ItemCode,
        i.ItemName,
        i.ItemName2,
        CASE WHEN @ShareQuoteId IS NOT NULL AND @HasOwnList = 0 THEN CONVERT(bit, 1) ELSE CONVERT(bit, 0) END AS IsShared,
        p.Price,
        iu.Unit,
        v.RootNode,
        v.Cat0,
        v.Cat1,
        i.PackSize
    FROM dbo.ItemQuote AS iq
    INNER JOIN dbo.Item AS i
        ON iq.ItemId = i.ItemId
    LEFT JOIN dbo.ItemUnit AS iu
        ON iq.ItemUnitId = iu.ItemUnitId
    LEFT JOIN dbo.View_Category AS v
        ON i.CategoryId = v.CategoryId
    OUTER APPLY
    (
        SELECT Price
        FROM dbo.Fn_GetPrice(@EffectivePayeeId, iq.ItemId, iq.ItemUnitId)
    ) AS p
    WHERE iq.PayeeId = @EffectivePayeeId
    ORDER BY v.Sort0, v.Sort1, v.Sort2, i.ItemName;
END
