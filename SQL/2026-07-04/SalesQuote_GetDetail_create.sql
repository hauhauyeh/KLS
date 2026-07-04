SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[SalesQuote_GetDetail]
    @SalesQuoteId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        sqd.SalesQuoteDetailId,
        sqd.SalesQuoteId,
        sqd.LineId,
        sqd.ItemId,
        sqd.ItemUnitId,
        sqd.Unit,
        sqd.OrdQty,
        sqd.UnitPrice,
        sqd.ExtTotal,
        sqd.DiscountPercent,
        sqd.Notes,
        sqd.IsTaxable,
        i.ItemName,
        i.ItemCode
    FROM dbo.SalesQuoteDetail AS sqd
    LEFT JOIN dbo.Item AS i
        ON i.ItemId = sqd.ItemId
    WHERE sqd.SalesQuoteId = @SalesQuoteId
    ORDER BY sqd.LineId;
END
GO
