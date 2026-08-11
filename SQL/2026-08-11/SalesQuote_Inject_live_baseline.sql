
-- ============================================================
-- SalesQuote_Inject
-- 2026-07-09: carry LineType + AccountId from SalesQuoteDetail
--   back into TempSalesQuote when opening a quote for edit, so
--   existing freight/account lines reload into the cart.
-- ============================================================
CREATE   PROCEDURE [dbo].[SalesQuote_Inject]
    @EmpId          INT,
    @SalesQuoteId   INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PayeeId INT;
    SELECT @PayeeId = PayeeId FROM SalesQuote WHERE SalesQuoteId = @SalesQuoteId;

    DELETE FROM TempSalesQuote WHERE EmpId = @EmpId AND SalesQuoteId = @SalesQuoteId;

    INSERT INTO TempSalesQuote (
        EmpId, SalesQuoteId, PayeeId, LineId,
        LineType, ItemId, AccountId, ItemUnitId, Unit,
        OrdQty, UnitPrice, ExtTotal,
        DiscountPercent, FactorToBase,
        Notes, IsTaxable, ChangeStatus, IsStrike
    )
    SELECT
        @EmpId, @SalesQuoteId, @PayeeId, sqd.SalesQuoteDetailId,
        ISNULL(sqd.LineType, 'I'), sqd.ItemId, sqd.AccountId, sqd.ItemUnitId, sqd.Unit,
        sqd.OrdQty, sqd.UnitPrice, sqd.ExtTotal,
        sqd.DiscountPercent, sqd.FactorToBase,
        sqd.Notes, sqd.IsTaxable, 'U', 0
    FROM SalesQuoteDetail sqd
    WHERE sqd.SalesQuoteId = @SalesQuoteId
    ORDER BY sqd.LineId;
END
