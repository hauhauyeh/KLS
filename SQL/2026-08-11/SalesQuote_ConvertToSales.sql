SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- SalesQuote_ConvertToSales
-- 2026-08-11: harden normal quote conversion.
--   - require an existing NormalSalesQuote (null/blank legacy values normalize to NormalSalesQuote)
--   - require Accepted status
--   - reject already converted quotes
--   - preserve item and account lines in TempSales
--   - do not open an outer transaction around Sales_Insert
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[SalesQuote_ConvertToSales]
    @SalesQuoteId   INT,
    @EmpId          INT,
    @NewSalesId     INT OUTPUT,
    @NewSalesNumber INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NewSalesId = 0;
    SET @NewSalesNumber = 0;

    DECLARE
        @PayeeId INT,
        @QuoteNumber INT,
        @Instruction NVARCHAR(300),
        @StatusId INT,
        @ExistingSalesId INT,
        @SalesQuoteType NVARCHAR(30),
        @QuoteLockResult INT,
        @QuoteLockResource NVARCHAR(100);

    SET @QuoteLockResource = 'SalesQuote_Convert_' + CONVERT(NVARCHAR(20), @SalesQuoteId);

    EXEC @QuoteLockResult = sp_getapplock
        @Resource = @QuoteLockResource,
        @LockMode = 'Exclusive',
        @LockOwner = 'Session',
        @LockTimeout = 0;

    IF @QuoteLockResult < 0
    BEGIN
        RAISERROR('This sales quote is already being converted.', 16, 1);
        RETURN;
    END

    BEGIN TRY

    SELECT
        @PayeeId = PayeeId,
        @QuoteNumber = QuoteNumber,
        @StatusId = StatusId,
        @ExistingSalesId = SalesId,
        @SalesQuoteType = ISNULL(NULLIF(LTRIM(RTRIM(SalesQuoteType)), ''), 'NormalSalesQuote')
    FROM SalesQuote
    WHERE SalesQuoteId = @SalesQuoteId;

    IF @PayeeId IS NULL
    BEGIN
        RAISERROR('Sales quote not found.', 16, 1);
    END

    IF @SalesQuoteType <> 'NormalSalesQuote'
    BEGIN
        RAISERROR('Only NormalSalesQuote can convert to a normal Sales Order.', 16, 1);
    END

    IF @StatusId = 5 OR @ExistingSalesId IS NOT NULL
    BEGIN
        RAISERROR('Sales quote is already converted.', 16, 1);
    END

    IF @StatusId <> 2
    BEGIN
        RAISERROR('Sales quote must be Accepted before conversion.', 16, 1);
    END

    IF NOT EXISTS (SELECT 1 FROM SalesQuoteDetail WHERE SalesQuoteId = @SalesQuoteId)
    BEGIN
        RAISERROR('Sales quote has no lines to convert.', 16, 1);
    END

    SET @Instruction = N'Quote #' + CONVERT(NVARCHAR(20), @QuoteNumber);

    -- Rebuild this emp+payee draft cart from the quote lines.
    DELETE FROM TempSales
    WHERE EmpId = @EmpId
      AND PayeeId = @PayeeId
      AND SalesId = 0;

    INSERT INTO TempSales
    (
        EmpId, SalesId, PayeeId, LineId, LineType,
        ItemId, AccountId, ItemUnitId, Unit,
        IsFree, IsOut, IsCRCG,
        OrdQty, ShipQty, BillQty,
        UnitPrice, Notes, IsTaxable, OrgPrice,
        DiscountPercent, FactorToBase,
        ChangeStatus, IsStrike, CartLineType, IsSystemManaged, DisplaySort
    )
    SELECT
        @EmpId, 0, @PayeeId, sqd.LineId, ISNULL(sqd.LineType, 'I'),
        sqd.ItemId, sqd.AccountId, sqd.ItemUnitId, sqd.Unit,
        0, 0, 0,
        sqd.OrdQty, sqd.OrdQty, sqd.OrdQty,
        sqd.UnitPrice, sqd.Notes, sqd.IsTaxable, sqd.UnitPrice,
        sqd.DiscountPercent, sqd.FactorToBase,
        'I', 0, 'MAIN', 0, sqd.LineId
    FROM SalesQuoteDetail sqd
    WHERE sqd.SalesQuoteId = @SalesQuoteId
    ORDER BY sqd.LineId;

    -- Sales_Insert owns its own transaction and applock.
    EXEC [Sales_Insert]
        @SalesId        = 0,
        @PayeeId        = @PayeeId,
        @ShipDate       = NULL,
        @ShipRoute      = NULL,
        @Instruction    = @Instruction,
        @StageId        = 0,
        @EmpId          = @EmpId,
        @NewSalesId     = @NewSalesId OUTPUT,
        @DocType        = 'SO';

    IF @NewSalesId > 0
    BEGIN
        SELECT @NewSalesNumber = SalesNumber
        FROM Sales
        WHERE SalesId = @NewSalesId;

        UPDATE SalesQuote
        SET
            StatusId = 5,
            SalesId = @NewSalesId,
            Updateby = @EmpId,
            UpdatedAt = GETUTCDATE()
        WHERE SalesQuoteId = @SalesQuoteId;
    END

    EXEC sp_releaseapplock
        @Resource = @QuoteLockResource,
        @LockOwner = 'Session';
    END TRY
    BEGIN CATCH
        EXEC sp_releaseapplock
            @Resource = @QuoteLockResource,
            @LockOwner = 'Session';
        THROW;
    END CATCH
END
GO
