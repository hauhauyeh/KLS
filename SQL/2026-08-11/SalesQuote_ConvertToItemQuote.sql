SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- SalesQuote_ConvertToItemQuote
-- 2026-08-11: convert an accepted PriceProposal into customer
-- ItemQuote rows by upserting quoted item/unit prices.
--
-- This conversion does not create Sales/Purchase documents and
-- intentionally leaves SalesQuote.SalesId unchanged.
-- ============================================================
CREATE OR ALTER PROCEDURE [dbo].[SalesQuote_ConvertToItemQuote] -- DECLARE @InsertedCount INT, @UpdatedCount INT; EXEC dbo.SalesQuote_ConvertToItemQuote @SalesQuoteId = 0, @EmpId = 0, @InsertedCount = @InsertedCount OUTPUT, @UpdatedCount = @UpdatedCount OUTPUT; SELECT @InsertedCount, @UpdatedCount;
    @SalesQuoteId   INT,
    @EmpId          INT,
    @InsertedCount  INT OUTPUT,
    @UpdatedCount   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @InsertedCount = 0;
    SET @UpdatedCount = 0;

    DECLARE
        @PayeeId INT,
        @StatusId INT,
        @ExistingSalesId INT,
        @SalesQuoteType NVARCHAR(30),
        @QuoteLockResult INT,
        @QuoteLockResource NVARCHAR(100),
        @DuplicateItemUnit NVARCHAR(200),
        @InvalidItemUnit NVARCHAR(200),
        @InvalidPriceItemUnit NVARCHAR(200);

    DECLARE @ProposalLines TABLE
    (
        ItemId INT NOT NULL,
        ItemUnitId INT NOT NULL PRIMARY KEY,
        UnitPrice DECIMAL(18,4) NOT NULL
    );

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
        @StatusId = StatusId,
        @ExistingSalesId = SalesId,
        @SalesQuoteType = ISNULL(NULLIF(LTRIM(RTRIM(SalesQuoteType)), ''), 'NormalSalesQuote')
    FROM SalesQuote
    WHERE SalesQuoteId = @SalesQuoteId;

    IF @PayeeId IS NULL
    BEGIN
        RAISERROR('Sales quote not found.', 16, 1);
    END

    IF @SalesQuoteType <> 'PriceProposal'
    BEGIN
        RAISERROR('Only PriceProposal can convert to Item Quote.', 16, 1);
    END

    IF @StatusId = 5
    BEGIN
        RAISERROR('Price Proposal is already converted.', 16, 1);
    END

    IF @ExistingSalesId IS NOT NULL
    BEGIN
        RAISERROR('Price Proposal is linked to a Sales Order and cannot convert to Item Quote.', 16, 1);
    END

    IF @StatusId <> 2
    BEGIN
        RAISERROR('Price Proposal must be Accepted before conversion.', 16, 1);
    END

    IF EXISTS
    (
        SELECT 1
        FROM SalesQuoteDetail
        WHERE SalesQuoteId = @SalesQuoteId
          AND LineType <> 'I'
    )
    BEGIN
        RAISERROR('Price Proposal can contain item lines only. Remove account lines before converting.', 16, 1);
    END

    IF NOT EXISTS
    (
        SELECT 1
        FROM SalesQuoteDetail
        WHERE SalesQuoteId = @SalesQuoteId
          AND LineType = 'I'
    )
    BEGIN
        RAISERROR('Price Proposal must have at least one item line.', 16, 1);
    END

    SELECT TOP (1)
        @InvalidItemUnit = COALESCE(i.ItemCode, 'ItemId ' + CONVERT(NVARCHAR(20), sqd.ItemId)) + ' ' + COALESCE(sqd.Unit, '')
    FROM SalesQuoteDetail sqd
    LEFT JOIN Item i ON i.ItemId = sqd.ItemId
    WHERE sqd.SalesQuoteId = @SalesQuoteId
      AND sqd.LineType = 'I'
      AND (sqd.ItemId IS NULL OR sqd.ItemUnitId IS NULL);

    IF @InvalidItemUnit IS NOT NULL
    BEGIN
        RAISERROR('Price Proposal has an item line missing item/unit: %s.', 16, 1, @InvalidItemUnit);
    END

    SELECT TOP (1)
        @InvalidItemUnit = COALESCE(i.ItemCode, 'ItemId ' + CONVERT(NVARCHAR(20), sqd.ItemId)) + ' ' + COALESCE(iu.Unit, sqd.Unit, '')
    FROM SalesQuoteDetail sqd
    LEFT JOIN Item i ON i.ItemId = sqd.ItemId
    LEFT JOIN ItemUnit iu ON iu.ItemUnitId = sqd.ItemUnitId
    WHERE sqd.SalesQuoteId = @SalesQuoteId
      AND sqd.LineType = 'I'
      AND (iu.ItemUnitId IS NULL OR iu.ItemId <> sqd.ItemId);

    IF @InvalidItemUnit IS NOT NULL
    BEGIN
        RAISERROR('Price Proposal has an item/unit mismatch: %s. Fix the line before converting.', 16, 1, @InvalidItemUnit);
    END

    SELECT TOP (1)
        @InvalidPriceItemUnit = COALESCE(i.ItemCode, 'ItemId ' + CONVERT(NVARCHAR(20), sqd.ItemId)) + ' ' + COALESCE(iu.Unit, sqd.Unit, '')
    FROM SalesQuoteDetail sqd
    LEFT JOIN Item i ON i.ItemId = sqd.ItemId
    LEFT JOIN ItemUnit iu ON iu.ItemUnitId = sqd.ItemUnitId
    WHERE sqd.SalesQuoteId = @SalesQuoteId
      AND sqd.LineType = 'I'
      AND ISNULL(sqd.UnitPrice, 0) <= 0;

    IF @InvalidPriceItemUnit IS NOT NULL
    BEGIN
        RAISERROR('Price Proposal has a zero or missing price: %s. Enter a price before converting.', 16, 1, @InvalidPriceItemUnit);
    END

    SELECT TOP (1)
        @DuplicateItemUnit = COALESCE(i.ItemCode, 'ItemId ' + CONVERT(NVARCHAR(20), MIN(sqd.ItemId))) + ' ' + COALESCE(iu.Unit, MIN(sqd.Unit), '')
    FROM SalesQuoteDetail sqd
    LEFT JOIN Item i ON i.ItemId = sqd.ItemId
    LEFT JOIN ItemUnit iu ON iu.ItemUnitId = sqd.ItemUnitId
    WHERE sqd.SalesQuoteId = @SalesQuoteId
      AND sqd.LineType = 'I'
    GROUP BY sqd.ItemUnitId, i.ItemCode, iu.Unit
    HAVING COUNT(*) > 1;

    IF @DuplicateItemUnit IS NOT NULL
    BEGIN
        RAISERROR('Price Proposal has duplicate item/unit lines: %s. Remove duplicate lines before converting.', 16, 1, @DuplicateItemUnit);
    END

    INSERT INTO @ProposalLines
    (
        ItemId,
        ItemUnitId,
        UnitPrice
    )
    SELECT
        sqd.ItemId,
        sqd.ItemUnitId,
        sqd.UnitPrice
    FROM SalesQuoteDetail sqd
    WHERE sqd.SalesQuoteId = @SalesQuoteId
      AND sqd.LineType = 'I';

    BEGIN TRANSACTION;

        UPDATE iq
        SET
            iq.ItemId = src.ItemId,
            iq.TargetPrice = src.UnitPrice,
            iq.MarkupPercent = NULL,
            iq.IsFixed = 1,
            iq.Inactive = 0,
            iq.UpdatedAt = GETUTCDATE()
        FROM ItemQuote iq WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN @ProposalLines src
            ON src.ItemUnitId = iq.ItemUnitId
        WHERE iq.PayeeId = @PayeeId;

        SET @UpdatedCount = @@ROWCOUNT;

        INSERT INTO ItemQuote
        (
            PayeeId,
            ItemId,
            ItemUnitId,
            MarkupPercent,
            TargetPrice,
            NewPrice,
            OldPrice,
            IsFixed,
            Inactive,
            CreatedAt,
            UpdatedAt
        )
        SELECT
            @PayeeId,
            src.ItemId,
            src.ItemUnitId,
            NULL,
            src.UnitPrice,
            NULL,
            NULL,
            1,
            0,
            GETUTCDATE(),
            GETUTCDATE()
        FROM @ProposalLines src
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM ItemQuote iq WITH (UPDLOCK, HOLDLOCK)
            WHERE iq.PayeeId = @PayeeId
              AND iq.ItemUnitId = src.ItemUnitId
        );

        SET @InsertedCount = @@ROWCOUNT;

        UPDATE SalesQuote
        SET
            StatusId = 5,
            Updateby = @EmpId,
            UpdatedAt = GETUTCDATE()
        WHERE SalesQuoteId = @SalesQuoteId
          AND StatusId = 2;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('Price Proposal status changed before conversion completed.', 16, 1);
        END

    COMMIT TRANSACTION;

    EXEC sp_releaseapplock
        @Resource = @QuoteLockResource,
        @LockOwner = 'Session';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        EXEC sp_releaseapplock
            @Resource = @QuoteLockResource,
            @LockOwner = 'Session';

        THROW;
    END CATCH
END
GO
