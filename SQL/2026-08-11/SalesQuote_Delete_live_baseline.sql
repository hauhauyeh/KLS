
-- ============================================
-- SalesQuote_Delete
-- ============================================
CREATE PROCEDURE [dbo].[SalesQuote_Delete]
    @SalesQuoteId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM SalesQuote WHERE SalesQuoteId = @SalesQuoteId AND StatusId IN (0, 3, 4))
    BEGIN
        RAISERROR('Cannot delete a quote that is Sent, Accepted, or Converted.', 16, 1);
        RETURN;
    END

    DELETE FROM SalesQuoteDetail WHERE SalesQuoteId = @SalesQuoteId;
    DELETE FROM SalesQuote WHERE SalesQuoteId = @SalesQuoteId;
END
