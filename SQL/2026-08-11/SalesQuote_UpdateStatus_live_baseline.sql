
-- ============================================
-- SalesQuote_UpdateStatus
-- ============================================
CREATE PROCEDURE [dbo].[SalesQuote_UpdateStatus]
    @SalesQuoteId   INT,
    @StatusId       INT,
    @EmpId          INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE SalesQuote SET
        StatusId = @StatusId,
        Updateby = @EmpId,
        UpdatedAt = GETUTCDATE()
    WHERE SalesQuoteId = @SalesQuoteId;
END
