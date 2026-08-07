SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- SalesQuote_Update
-- 2026-07-09: carry LineType + AccountId through the edit path
--   (update-changed rows keep their type; insert-new rows carry
--   LineType/AccountId). Delete-removed / match-by-LineId logic
--   unchanged. Totals sum all rows (account lines included).
-- 2026-08-06: calculate BaseOrdQty from full ItemUnit ratio
--   (MultipleToBase / FactorToBase) so combine-up units work.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[SalesQuote_Update]
    @SalesQuoteId   INT,
    @EmpId          INT,
    @PayeeId        INT,
    @ExpiryDate     DATE = NULL,
    @Notes          NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TaxRate        DECIMAL(18, 4);
    DECLARE @SubTotal       DECIMAL(18, 2);
    DECLARE @TaxableTotal   DECIMAL(18, 2);
    DECLARE @TaxTotal       DECIMAL(18, 2);
    DECLARE @QuoteTotal     DECIMAL(18, 2);

    SELECT
        @TaxRate = TaxPercent
    FROM SalesQuote
    WHERE SalesQuoteId = @SalesQuoteId;

    DELETE FROM SalesQuoteDetail
    WHERE SalesQuoteId = @SalesQuoteId
      AND SalesQuoteDetailId NOT IN
      (
          SELECT LineId
          FROM TempSalesQuote
          WHERE EmpId = @EmpId
            AND PayeeId = @PayeeId
            AND SalesQuoteId = @SalesQuoteId
            AND LineId IS NOT NULL
            AND IsStrike = 0
      );

    UPDATE sqd
    SET
        sqd.LineType = ISNULL(t.LineType, 'I'),
        sqd.AccountId = t.AccountId,
        sqd.OrdQty = t.OrdQty,
        sqd.UnitPrice = t.UnitPrice,
        sqd.ExtTotal = ROUND(ISNULL(t.OrdQty, 0) * ISNULL(t.UnitPrice, 0), 2),
        sqd.ItemUnitId = t.ItemUnitId,
        sqd.Unit = t.Unit,
        sqd.FactorToBase = t.FactorToBase,
        sqd.BaseOrdQty = CASE
            WHEN t.ItemUnitId IS NULL THEN NULL
            -- Prior logic divided OrdQty by FactorToBase only, which missed combine-up units.
            ELSE dbo.Fn_QtyToBase(t.OrdQty, iu.MultipleToBase, iu.FactorToBase)
        END,
        sqd.DiscountPercent = t.DiscountPercent,
        sqd.Notes = t.Notes,
        sqd.IsTaxable = t.IsTaxable
    FROM SalesQuoteDetail AS sqd
    INNER JOIN TempSalesQuote AS t
        ON t.LineId = sqd.SalesQuoteDetailId
    LEFT JOIN dbo.ItemUnit AS iu
        ON iu.ItemUnitId = t.ItemUnitId
    WHERE t.EmpId = @EmpId
      AND t.PayeeId = @PayeeId
      AND t.SalesQuoteId = @SalesQuoteId
      AND t.ChangeStatus = 'U'
      AND t.IsStrike = 0;

    DECLARE @MaxLineId INT = ISNULL(
    (
        SELECT MAX(LineId)
        FROM SalesQuoteDetail
        WHERE SalesQuoteId = @SalesQuoteId
    ),
    0
    );

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
        @SalesQuoteId,
        @MaxLineId + ROW_NUMBER() OVER (ORDER BY t.TempSalesQuoteId),
        ISNULL(t.LineType, 'I'),
        t.ItemId,
        t.AccountId,
        t.ItemUnitId,
        t.Unit,
        t.OrdQty,
        t.UnitPrice,
        ROUND(ISNULL(t.OrdQty, 0) * ISNULL(t.UnitPrice, 0), 2),
        t.FactorToBase,
        CASE
            WHEN t.ItemUnitId IS NULL THEN NULL
            -- Prior logic divided OrdQty by FactorToBase only, which missed combine-up units.
            ELSE dbo.Fn_QtyToBase(t.OrdQty, iu.MultipleToBase, iu.FactorToBase)
        END,
        t.DiscountPercent,
        t.Notes,
        t.IsTaxable
    FROM TempSalesQuote AS t
    LEFT JOIN dbo.ItemUnit AS iu
        ON iu.ItemUnitId = t.ItemUnitId
    WHERE t.EmpId = @EmpId
      AND t.PayeeId = @PayeeId
      AND t.SalesQuoteId = @SalesQuoteId
      AND t.ChangeStatus = 'I'
      AND t.IsStrike = 0
    ORDER BY t.TempSalesQuoteId;

    SELECT
        @SubTotal = ISNULL(SUM(ROUND(OrdQty * UnitPrice, 2)), 0)
    FROM SalesQuoteDetail
    WHERE SalesQuoteId = @SalesQuoteId;

    SELECT
        @TaxableTotal = ISNULL(SUM(ROUND(OrdQty * UnitPrice, 2)), 0)
    FROM SalesQuoteDetail
    WHERE SalesQuoteId = @SalesQuoteId
      AND IsTaxable = 1;

    SET @TaxTotal = ROUND(@TaxableTotal * @TaxRate, 2);
    SET @QuoteTotal = @SubTotal + @TaxTotal;

    UPDATE SalesQuote
    SET
        ExpiryDate = @ExpiryDate,
        SubTotal = @SubTotal,
        TaxableTotal = @TaxableTotal,
        TaxTotal = @TaxTotal,
        QuoteTotal = @QuoteTotal,
        Notes = @Notes,
        Updateby = @EmpId,
        UpdatedAt = GETUTCDATE()
    WHERE SalesQuoteId = @SalesQuoteId;

    DELETE FROM TempSalesQuote
    WHERE EmpId = @EmpId
      AND PayeeId = @PayeeId
      AND SalesQuoteId = @SalesQuoteId;
END;
GO
