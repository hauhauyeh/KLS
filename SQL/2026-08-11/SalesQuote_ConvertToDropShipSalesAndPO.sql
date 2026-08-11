SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- SalesQuote_ConvertToDropShipSalesAndPO
-- 2026-08-11: convert an accepted DropShipSalesQuote into the
-- linked drop-ship Sales Order and vendor PO by seeding TempSales
-- and reusing DropShipment_InsertSalesAndPO.
--
-- DropShipment_InsertSalesAndPO owns its core Sales/PO transaction;
-- this bridge does not open an outer transaction. The quote is linked
-- and marked Converted only after the drop-ship engine returns a SalesId.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[SalesQuote_ConvertToDropShipSalesAndPO]
    @SalesQuoteId       INT,
    @EmpId              INT,
    @VendorPayeeId      INT,
    @ShipDate           DATE = NULL,
    @FactorPO           NVARCHAR(100) = NULL,
    @CustPONumber       NVARCHAR(100) = NULL,
    @NewSalesId         INT OUTPUT,
    @NewSalesNumber     INT OUTPUT,
    @NewPurchaseId      INT OUTPUT,
    @NewPurchaseNumber  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NewSalesId = 0;
    SET @NewSalesNumber = 0;
    SET @NewPurchaseId = 0;
    SET @NewPurchaseNumber = 0;

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

    IF @SalesQuoteType <> 'DropShipSalesQuote'
    BEGIN
        RAISERROR('Only DropShipSalesQuote can convert to drop-ship Sales/PO.', 16, 1);
    END

    IF @StatusId = 5 OR @ExistingSalesId IS NOT NULL
    BEGIN
        RAISERROR('Sales quote is already converted.', 16, 1);
    END

    IF @StatusId <> 2
    BEGIN
        RAISERROR('Sales quote must be Accepted before conversion.', 16, 1);
    END

    IF ISNULL(@VendorPayeeId, 0) <= 0
    BEGIN
        RAISERROR('Vendor is required for drop-ship conversion.', 16, 1);
    END

    IF NOT EXISTS
    (
        SELECT 1
        FROM SalesQuoteDetail
        WHERE SalesQuoteId = @SalesQuoteId
          AND ISNULL(LineType, 'I') = 'I'
          AND ItemId IS NOT NULL
    )
    BEGIN
        RAISERROR('Drop-ship quote must have at least one item line.', 16, 1);
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

    EXEC [DropShipment_InsertSalesAndPO]
        @SalesId        = 0,
        @PayeeId        = @PayeeId,
        @VendorPayeeId  = @VendorPayeeId,
        @ShipDate       = @ShipDate,
        @ShipRoute      = NULL,
        @Instruction    = @Instruction,
        @EmpId          = @EmpId,
        @PurchaseDate   = NULL,
        @NewSalesId     = @NewSalesId OUTPUT,
        @NewPurchaseId  = @NewPurchaseId OUTPUT,
        @FactorPO       = @FactorPO,
        @CustPONumber   = @CustPONumber,
        @SourceSalesId  = NULL;

    IF ISNULL(@NewSalesId, 0) <= 0 OR ISNULL(@NewPurchaseId, 0) <= 0
    BEGIN
        RAISERROR('Drop-ship conversion did not return linked Sales/PO ids.', 16, 1);
    END

    IF @NewSalesId > 0 AND @NewPurchaseId > 0
    BEGIN
        SELECT @NewSalesNumber = SalesNumber
        FROM Sales
        WHERE SalesId = @NewSalesId;

        SELECT @NewPurchaseNumber = PurchaseNumber
        FROM Purchase
        WHERE PurchaseId = @NewPurchaseId;

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
