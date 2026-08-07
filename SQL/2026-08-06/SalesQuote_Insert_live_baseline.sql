
-- ============================================================
-- SalesQuote_Insert
-- 2026-07-09: carry LineType + AccountId from TempSalesQuote
--   into SalesQuoteDetail so freight/account lines persist.
--   Account lines: FactorToBase/BaseOrdQty stay NULL (no unit),
--   IsTaxable already 0 from temp; totals sum all rows.
-- ============================================================
CREATE   PROCEDURE [dbo].[SalesQuote_Insert]
    @SalesQuoteId       INT,
    @PayeeId            INT,
    @EmpId              INT,
    @ExpiryDate         DATE = NULL,
    @Notes              NVARCHAR(500) = NULL,
    @StatusId           INT = 0,
    @NewSalesQuoteId    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewQuoteNumber INT = NEXT VALUE FOR dbo.Seq_SalesQuoteNumber;
    DECLARE @TaxRate        DECIMAL(18, 4);
    DECLARE @TermId         INT;
    DECLARE @SalesRepId     INT;

    SELECT
        @TermId = TermId,
        @TaxRate = c.TaxRate,
        @SalesRepId = ISNULL(c.SalesRepId, @EmpId)
    FROM Payee AS p
    INNER JOIN Customer AS c
        ON p.PayeeId = c.PayeeId
    WHERE p.PayeeId = @PayeeId;

    DECLARE @SubTotal       DECIMAL(18, 2);
    DECLARE @TaxableTotal   DECIMAL(18, 2);
    DECLARE @TaxTotal       DECIMAL(18, 2);
    DECLARE @QuoteTotal     DECIMAL(18, 2);


    INSERT INTO SalesQuote
    (
        QuoteNumber,
        QuoteDate,
        ExpiryDate,
        PayeeId,
        SalesRepId,
        TermId,
        SubTotal,
        TaxableTotal,
        TaxPercent,
        TaxTotal,
        QuoteTotal,
        StatusId,
        Notes,
        Enterby,
        CreatedAt
    )
    VALUES
    (
        @NewQuoteNumber,
        GETUTCDATE(),
        @ExpiryDate,
        @PayeeId,
        @SalesRepId,
        @TermId,
        @SubTotal,
        @TaxableTotal,
        @TaxRate,
        @TaxTotal,
        @SubTotal + @TaxTotal,
        @StatusId,
        @Notes,
        @EmpId,
        GETUTCDATE()
    );

    SET @NewSalesQuoteId = SCOPE_IDENTITY();

    INSERT INTO SalesQuoteDetail
    (
        SalesQuoteId,
        LineId,
        LineType,
        ItemId,
        AccountId,
        ItemUnitId,
        Unit,
        OrdQty,
        UnitPrice,
        ExtTotal,
        FactorToBase,
        BaseOrdQty,
        DiscountPercent,
        Notes,
        IsTaxable
    )
    SELECT
        @NewSalesQuoteId,
        ROW_NUMBER() OVER (ORDER BY TempSalesQuoteId),
        ISNULL(LineType, 'I'),
        ItemId,
        AccountId,
        ItemUnitId,
        Unit,
        OrdQty,
        UnitPrice,
        ROUND(ISNULL(OrdQty, 0) * ISNULL(UnitPrice, 0), 2),
        FactorToBase,
        ROUND(OrdQty / NULLIF(FactorToBase, 0), 6),
        DiscountPercent,
        Notes,
        IsTaxable
    FROM TempSalesQuote
    WHERE EmpId = @EmpId
      AND PayeeId = @PayeeId
      AND SalesQuoteId = @SalesQuoteId
      AND IsStrike = 0
    ORDER BY TempSalesQuoteId;

    SELECT @SubTotal = ISNULL(SUM(ROUND(OrdQty * UnitPrice, 2)), 0)
    FROM SalesQuoteDetail
    WHERE SalesQuoteId = @NewSalesQuoteId;

    SELECT @TaxableTotal = ISNULL(SUM(ROUND(OrdQty * UnitPrice, 2)), 0)
    FROM SalesQuoteDetail
    WHERE SalesQuoteId = @NewSalesQuoteId AND IsTaxable = 1;

    SET @TaxTotal = ROUND(@TaxableTotal * @TaxRate, 2);
    SET @QuoteTotal = @SubTotal + @TaxTotal;

    UPDATE SalesQuote
    SET
        SubTotal = @SubTotal,
        TaxableTotal = @TaxableTotal,
        TaxTotal = @TaxTotal,
        QuoteTotal = @QuoteTotal
    WHERE SalesQuoteId = @NewSalesQuoteId;

    DELETE FROM TempSalesQuote
    WHERE EmpId = @EmpId
      AND PayeeId = @PayeeId
      AND SalesQuoteId = @SalesQuoteId;
END;
