
-- ============================================================
-- SalesQuote_ConvertToSales  (one-click auto-create -- Option B)
-- 2026-07-09: convert now POSTS the actual order in one call
--   (pattern of MarketPlaceOrder_Convert):
--     1. rebuild 
the emp+payee draft cart from the quote lines
--        (items AND account/freight lines -> carry LineType/AccountId),
--     2. EXEC Sales_Insert to create Sales + SalesDetail + journal
--        and drain the cart,
--     3. link the quote to the new or
der and mark it Converted,
--        returning the new SalesId + SalesNumber.
--   Signature adds @NewSalesId / @NewSalesNumber OUTPUT.
--
-- Error safety: Sales_Insert is fully atomic on its own (own
--   transaction + applock, THROWs on failure). No ext
ra outer
--   transaction is opened here (would nest inside Sales_Insert).
--   With XACT_ABORT ON a failed post aborts the batch, so the
--   quote is NOT marked converted and NO Sales/journal rows are
--   created; the only residue is the SalesId=0 pre-
fill cart,
--   which is re-DELETEd at the top of the next convert/checkout.
-- ============================================================
CREATE   PROCEDURE [dbo].[SalesQuote_ConvertToSales]
    @SalesQuoteId   INT,
    @EmpId          INT,
    @NewSal
esId     INT OUTPUT,
    @NewSalesNumber INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NewSalesId = 0;
    SET @NewSalesNumber = 0;

    DECLARE @PayeeId INT, @QuoteNumber INT, @Instruction NVARCHAR(300);

    SELECT @PayeeId = 
PayeeId, @QuoteNumber = QuoteNumber
    FROM SalesQuote
    WHERE SalesQuoteId = @SalesQuoteId;

    SET @Instruction = N'Quote #' + CONVERT(NVARCHAR(20), @QuoteNumber);

    -- Rebuild this emp+payee draft cart from the quote lines (items + accounts)
   
 DELETE FROM TempSales
    WHERE EmpId = @EmpId AND PayeeId = @PayeeId AND SalesId = 0;

    INSERT INTO TempSales (
        EmpId, SalesId, PayeeId, LineType,
        ItemId, AccountId, ItemUnitId, Unit,
        OrdQty, ShipQty, BillQty,
        UnitPric
e, Notes, IsTaxable, OrgPrice,
        DiscountPercent, FactorToBase,
        ChangeStatus, IsStrike, CartLineType
    )
    SELECT
        @EmpId, 0, @PayeeId, ISNULL(sqd.LineType, 'I'),
        sqd.ItemId, sqd.AccountId, sqd.ItemUnitId, sqd.Unit,
      
  sqd.OrdQty, sqd.OrdQty, sqd.OrdQty,
        sqd.UnitPrice, sqd.Notes, sqd.IsTaxable, sqd.UnitPrice,
        sqd.DiscountPercent, sqd.FactorToBase,
        'I', 0, 'MAIN'
    FROM SalesQuoteDetail sqd
    WHERE sqd.SalesQuoteId = @SalesQuoteId
    ORDER 
BY sqd.LineId;

    -- Post the real order from the cart (handles items + account lines +
    -- journal + cart cleanup, all inside Sales_Insert's own transaction).
    EXEC [Sales_Insert]
        @SalesId        = 0,
        @PayeeId        = @PayeeId,
 
       @ShipDate       = NULL,           -- Sales_Insert computes via Fn_Calc_NextShipDate
        @ShipRoute      = NULL,
        @Instruction    = @Instruction,
        @StageId        = 0,              -- standard new-order draft stage (matches Sales/C
heckout)
        @EmpId          = @EmpId,
        @NewSalesId     = @NewSalesId OUTPUT,
        @DocType        = 'SO';

    -- Link + mark converted only after a real order exists
    IF @NewSalesId > 0
    BEGIN
        SELECT @NewSalesNumber = SalesNu
mber FROM Sales WHERE SalesId = @NewSalesId;

        UPDATE SalesQuote SET
            StatusId  = 5,
            SalesId   = @NewSalesId,
            Updateby  = @EmpId,
            UpdatedAt = GETUTCDATE()
        WHERE SalesQuoteId = @SalesQuoteId;
  
  END
END


