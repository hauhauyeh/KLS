SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- SalesQuote_Insert
-- 2026-07-09: carry LineType + AccountId from TempSalesQuote
--   into SalesQuoteDetail so freight/account lines persist.
--   Account lines: FactorToBase/BaseOrdQty stay NULL (no unit),
--   IsTaxable already 0 from temp; totals sum all rows.
-- 2026-08-06: calculate BaseOrdQty from full ItemUnit ratio
--   (MultipleToBase / FactorToBase) so combine-up units work.
-- 2026-08-11: accept optional SalesQuoteType and default old callers
--   to NormalSalesQuote.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[SalesQuote_Insert]
    @SalesQuoteId       INT,
    @PayeeId            INT,
    @EmpId              INT,
    @ExpiryDate         DATE = NULL,
    @Notes              NVARCHAR(500) = NULL,
    @StatusId           INT = 0,
    @NewSalesQuoteId    INT OUTPUT,
    @SalesQuoteType     NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NewQuoteNumber INT = NEXT VALUE FOR dbo.Seq_SalesQuoteNumber;
    DECLARE @TaxRate        DECIMAL(18, 4);
    DECLARE @TermId         INT;
    DECLARE @SalesRepId     INT;
    DECLARE @EffectiveSalesQuoteType NVARCHAR(30) = ISNULL(NULLIF(LTRIM(RTRIM(@SalesQuoteType)), ''), 'NormalSalesQuote');

    IF @EffectiveSalesQuoteType NOT IN ('NormalSalesQuote', 'DropShipSalesQuote', 'PriceProposal')
    BEGIN
        RAISERROR('Invalid SalesQuoteType.', 16, 1);
        RETURN;
    END

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
        SalesQuoteType,
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
        @EffectiveSalesQuoteType,
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
        ROW_NUMBER() OVER (ORDER BY ts.TempSalesQuoteId),
        ISNULL(ts.LineType, 'I'),
        ts.ItemId,
        ts.AccountId,
        ts.ItemUnitId,
        ts.Unit,
        ts.OrdQty,
        ts.UnitPrice,
        ROUND(ISNULL(ts.OrdQty, 0) * ISNULL(ts.UnitPrice, 0), 2),
        ts.FactorToBase,
        CASE
            WHEN ts.ItemUnitId IS NULL THEN NULL
            -- Prior logic divided OrdQty by FactorToBase only, which missed combine-up units.
            ELSE dbo.Fn_QtyToBase(ts.OrdQty, iu.MultipleToBase, iu.FactorToBase)
        END,
        ts.DiscountPercent,
        ts.Notes,
        ts.IsTaxable
    FROM TempSalesQuote AS ts
    LEFT JOIN dbo.ItemUnit AS iu
        ON iu.ItemUnitId = ts.ItemUnitId
    WHERE ts.EmpId = @EmpId
      AND ts.PayeeId = @PayeeId
      AND ts.SalesQuoteId = @SalesQuoteId
      AND ts.IsStrike = 0
    ORDER BY ts.TempSalesQuoteId;

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
GO
