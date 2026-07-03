SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
DROP FUNCTION IF EXISTS [dbo].[Fn_ItemUnit_IsUsed]
GO
CREATE FUNCTION [dbo].[Fn_ItemUnit_IsUsed] (@ItemUnitId INT)  -- SELECT dbo.Fn_ItemUnit_IsUsed(4196)
RETURNS BIT
AS
BEGIN
    -- Returns 1 if @ItemUnitId is referenced in ANY of the 13 tables carrying ItemUnitId (incl. the Temp*
    -- drafts), else 0. A unit sitting in an open draft counts as in-use (deleting it would orphan the draft).
    -- Used by the DeleteUnit guard (delete only UNUSED units; used units must be inactivated) and the Phase-D
    -- orphan audit. The 13 tables were discovered from sys.columns LIKE '%ItemUnitId%' (2026-07-02); only 3 of
    -- them (SalesQuoteDetail, MarketOrderItem, MarketItemMap) have real FKs, which is why this explicit check
    -- exists. Pure EXISTS reads => inlineable.
    IF EXISTS (SELECT 1 FROM SalesDetail      WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM PurchaseDetail   WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM ItemQuote        WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM SalesRouteDetail WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM CartItem         WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM SalesQuoteDetail WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM MarketOrderItem  WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM MarketItemMap    WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM TempSales        WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM TempPurchase     WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM TempBombSales    WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM TempSalesQuote   WHERE ItemUnitId = @ItemUnitId)
    OR EXISTS (SELECT 1 FROM TempItemQuote    WHERE ItemUnitId = @ItemUnitId)
        RETURN 1;
    RETURN 0;
END
GO
